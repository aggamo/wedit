// =============================================================
// Edge Function: process-active-days (cron)
// Runs daily to count active riding days, update streaks,
// apply XP penalties for inactivity, and recalculate
// personal ride goals for all drivers with active subscriptions.
// Auth: service_role only.
// =============================================================
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const JSON_HEADERS = { ...CORS_HEADERS, "Content-Type": "application/json" };

interface DriverSubscription {
  id: string;
  driver_id: string;
  ends_at: string | null;
  active_days_used: number;
  active_days_quota: number | null;
  last_active_date: string | null;
  no_expiry: boolean;
  subscription_plans: {
    use_active_days: boolean;
    features: Record<string, unknown>;
  } | null;
}

interface StreakConfig {
  days: number;
  reward_points: number;
  reward_xp: number;
  description_ar: string;
}

/** Format date as YYYY-MM-DD in UTC */
function toDateString(d: Date): string {
  return d.toISOString().slice(0, 10);
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS_HEADERS });
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "الطريقة غير مسموح بها" }), {
      status: 405,
      headers: JSON_HEADERS,
    });
  }

  const supabaseUrl    = Deno.env.get("SUPABASE_URL")!;
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  // Auth: service_role only
  const authHeader = req.headers.get("authorization") ?? "";
  if (!authHeader.includes(serviceRoleKey)) {
    return new Response(JSON.stringify({ error: "غير مصرح — يتطلب service_role" }), {
      status: 401,
      headers: JSON_HEADERS,
    });
  }

  const svc = createClient(supabaseUrl, serviceRoleKey);

  try {
    // 1. Fetch global settings
    const { data: settings } = await svc
      .from("subscription_settings")
      .select(
        "active_day_min_rides, active_day_min_hours, inactive_xp_penalty_per_day, inactive_level_decay_days, personal_goal_window_days, personal_goal_multiplier"
      )
      .single();

    const minRides: number             = (settings?.active_day_min_rides as number)         ?? 6;
    const inactiveXpPenalty: number    = (settings?.inactive_xp_penalty_per_day as number)  ?? 10;
    const decayDays: number            = (settings?.inactive_level_decay_days as number)    ?? 14;
    const goalWindowDays: number       = (settings?.personal_goal_window_days as number)    ?? 14;
    const goalMultiplier: number       = (settings?.personal_goal_multiplier as number)     ?? 1.2;

    // 2. Fetch streak milestone configs
    const { data: streakConfigs } = await svc
      .from("streak_configs")
      .select("days, reward_points, reward_xp, description_ar")
      .order("days");

    const milestones: StreakConfig[] = (streakConfigs ?? []) as StreakConfig[];

    // 3. Fetch all active, non-frozen subscriptions with plan details
    const { data: activeSubs, error: subsErr } = await svc
      .from("driver_subscriptions")
      .select(`
        id,
        driver_id,
        ends_at,
        active_days_used,
        active_days_quota,
        last_active_date,
        no_expiry,
        subscription_plans (
          use_active_days,
          features
        )
      `)
      .eq("status", "active")
      .eq("is_frozen", false);

    if (subsErr) {
      return new Response(
        JSON.stringify({ error: "فشل جلب الاشتراكات", details: subsErr.message }),
        { status: 500, headers: JSON_HEADERS }
      );
    }

    const now       = new Date();
    const yesterday = new Date(now);
    yesterday.setUTCDate(yesterday.getUTCDate() - 1);
    const yesterdayStr = toDateString(yesterday);

    let processed         = 0;
    let activeDaysCounted = 0;
    const errors: string[] = [];

    const notifications: Array<{ user_id: string; title: string; body: string; type: string }> = [];

    // 4. Process each driver
    for (const sub of (activeSubs as unknown as DriverSubscription[]) ?? []) {
      try {
        const driverId = sub.driver_id;
        const plan     = sub.subscription_plans;

        // ── Trial plan (no active day counting) ─────────────────
        if (!plan?.use_active_days) {
          // Check expiry only
          if (sub.ends_at && !sub.no_expiry && new Date(sub.ends_at) <= now) {
            await svc
              .from("driver_subscriptions")
              .update({ status: "expired" })
              .eq("id", sub.id);
          }
          processed++;
          continue;
        }

        // ── Active days plan ─────────────────────────────────────

        // Count rides yesterday
        const { count: ridesYesterday } = await svc
          .from("rides")
          .select("*", { count: "exact", head: true })
          .eq("driver_id", driverId)
          .eq("status", "completed")
          .gte("completed_at", `${yesterdayStr}T00:00:00Z`)
          .lt("completed_at", `${toDateString(now)}T00:00:00Z`);

        const wasActive = (ridesYesterday ?? 0) >= minRides;

        // Fetch current streak
        const { data: streakRow } = await svc
          .from("driver_streaks")
          .select("current_streak, longest_streak, last_active_date, streak_frozen")
          .eq("driver_id", driverId)
          .maybeSingle();

        const streakFrozen      = (streakRow?.streak_frozen as boolean) ?? false;
        const currentStreak     = (streakRow?.current_streak as number) ?? 0;
        const longestStreak     = (streakRow?.longest_streak as number) ?? 0;
        const lastActiveDateStr = streakRow?.last_active_date as string | null;

        if (wasActive) {
          // ── Active day ─────────────────────────────────────────
          activeDaysCounted++;

          // Update subscription active_days_used
          const newActiveDaysUsed = (sub.active_days_used ?? 0) + 1;
          const subUpdate: Record<string, unknown> = {
            active_days_used: newActiveDaysUsed,
            last_active_date: yesterdayStr,
          };

          // Check if quota reached
          if (
            sub.active_days_quota !== null &&
            newActiveDaysUsed >= sub.active_days_quota &&
            !sub.no_expiry
          ) {
            subUpdate.status = "expired";
          }

          await svc.from("driver_subscriptions").update(subUpdate).eq("id", sub.id);

          // Update streak (unless frozen)
          if (!streakFrozen) {
            const dayBeforeYesterday = new Date(yesterday);
            dayBeforeYesterday.setUTCDate(dayBeforeYesterday.getUTCDate() - 1);

            const isConsecutive =
              lastActiveDateStr === toDateString(dayBeforeYesterday) || currentStreak === 0;

            const newStreak  = isConsecutive ? currentStreak + 1 : 1;
            const newLongest = Math.max(longestStreak, newStreak);

            await svc.from("driver_streaks").upsert(
              {
                driver_id:        driverId,
                current_streak:   newStreak,
                longest_streak:   newLongest,
                last_active_date: yesterdayStr,
              },
              { onConflict: "driver_id" }
            );

            // Sync best_streak to lifetime_stats whenever it improves
            if (newLongest > longestStreak) {
              await svc.from("driver_lifetime_stats").upsert(
                { driver_id: driverId, best_streak: newLongest },
                { onConflict: "driver_id", ignoreDuplicates: false }
              );
            }

            // Check streak milestones
            for (const milestone of milestones) {
              if (newStreak === milestone.days) {
                // Award milestone rewards
                if (milestone.reward_points > 0) {
                  const { data: profileRow } = await svc
                    .from("profiles")
                    .select("points")
                    .eq("id", driverId)
                    .single();

                  await svc
                    .from("profiles")
                    .update({ points: ((profileRow?.points as number) ?? 0) + milestone.reward_points })
                    .eq("id", driverId);

                  await svc.from("points_transactions").insert({
                    user_id:     driverId,
                    amount:      milestone.reward_points,
                    type:        "bonus",
                    description: milestone.description_ar || `مكافأة ${milestone.days} يوم متتالي`,
                  });
                }

                if (milestone.reward_xp > 0) {
                  await svc.from("driver_xp_transactions").insert({
                    driver_id:   driverId,
                    amount:      milestone.reward_xp,
                    type:        "streak_milestone",
                    description: milestone.description_ar || `XP ${milestone.days} يوم متتالي`,
                  });
                }
              }
            }
          }

          // Active day notification
          notifications.push({
            user_id: driverId,
            title:   "يوم نشط ✓",
            body:    `تم احتساب يوم نشط — رصيدك: ${newActiveDaysUsed} أيام`,
            type:    "active_day",
          });

        } else {
          // ── Inactive day ───────────────────────────────────────

          // Reset streak (unless frozen)
          if (!streakFrozen && currentStreak > 0) {
            await svc
              .from("driver_streaks")
              .update({ current_streak: 0 })
              .eq("driver_id", driverId);
          }

          // XP penalty for inactivity
          if (inactiveXpPenalty > 0) {
            await svc.from("driver_xp_transactions").insert({
              driver_id:   driverId,
              amount:      -inactiveXpPenalty,
              type:        "penalty_inactive",
              description: "خصم XP — يوم خمول",
            });
          }

          // Inactive notification
          notifications.push({
            user_id: driverId,
            title:   "يوم هادئ",
            body:    "لم يُحتسب اليوم من رصيدك — حاول إكمال المزيد من الرحلات",
            type:    "inactive_day",
          });
        }

        // ── Level decay check ──────────────────────────────────
        const decayThreshold = new Date(now);
        decayThreshold.setUTCDate(decayThreshold.getUTCDate() - decayDays);
        const lastActivityDate = lastActiveDateStr ? new Date(lastActiveDateStr) : null;

        if (!lastActivityDate || lastActivityDate < decayThreshold) {
          // Fetch current level and demote one step
          const { data: levelState } = await svc
            .from("driver_level_state")
            .select("level_id, level_definitions(sort_order)")
            .eq("driver_id", driverId)
            .maybeSingle();

          if (levelState?.level_id) {
            const currentSortOrder = (levelState.level_definitions as Record<string, unknown>)?.sort_order as number ?? 0;

            if (currentSortOrder > 0) {
              const { data: prevLevel } = await svc
                .from("level_definitions")
                .select("id")
                .lt("sort_order", currentSortOrder)
                .order("sort_order", { ascending: false })
                .limit(1)
                .maybeSingle();

              if (prevLevel) {
                await svc
                  .from("driver_level_state")
                  .update({ level_id: prevLevel.id })
                  .eq("driver_id", driverId);

                await svc.from("driver_xp_transactions").insert({
                  driver_id:   driverId,
                  amount:      -50,
                  type:        "penalty_inactive",
                  description: "تراجع المستوى للخمول",
                });
              }
            }
          }
        }

        // ── Update personal ride goal ──────────────────────────
        const goalWindowStart = new Date(now);
        goalWindowStart.setUTCDate(goalWindowStart.getUTCDate() - goalWindowDays);

        const { data: recentRides } = await svc
          .from("rides")
          .select("completed_at")
          .eq("driver_id", driverId)
          .eq("status", "completed")
          .gte("completed_at", goalWindowStart.toISOString());

        if (recentRides && recentRides.length > 0) {
          // Group by day and compute average
          const dayCounts: Record<string, number> = {};
          for (const ride of recentRides) {
            const day = (ride.completed_at as string).slice(0, 10);
            dayCounts[day] = (dayCounts[day] ?? 0) + 1;
          }
          const dayValues     = Object.values(dayCounts);
          const avgRidesPerDay = dayValues.reduce((a, b) => a + b, 0) / Math.max(dayValues.length, 1);
          const newDailyGoal   = Math.max(1, Math.ceil(avgRidesPerDay * goalMultiplier));

          await svc.from("driver_goal_state").upsert(
            {
              driver_id:        driverId,
              daily_goal_rides: newDailyGoal,
              computed_at:      toDateString(now),
            },
            { onConflict: "driver_id" }
          );
        }

        processed++;
      } catch (driverErr) {
        console.error(`Error processing driver ${sub.driver_id}:`, driverErr);
        errors.push(`driver ${sub.driver_id}: ${String(driverErr)}`);
      }
    }

    // 5. Fire notifications (non-blocking, batched)
    for (const notif of notifications) {
      fetch(`${supabaseUrl}/functions/v1/send-notification`, {
        method:  "POST",
        headers: {
          "Content-Type":  "application/json",
          "Authorization": `Bearer ${serviceRoleKey}`,
        },
        body: JSON.stringify(notif),
      }).catch((e) => console.warn("notification fire-and-forget failed:", e));
    }

    return new Response(
      JSON.stringify({
        success:             true,
        processed,
        active_days_counted: activeDaysCounted,
        errors,
      }),
      { status: 200, headers: JSON_HEADERS }
    );
  } catch (err) {
    console.error("process-active-days error:", err);
    return new Response(
      JSON.stringify({ error: "خطأ داخلي في الخادم", details: String(err) }),
      { status: 500, headers: JSON_HEADERS }
    );
  }
});
