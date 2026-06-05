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
  subscription_plans: {
    use_active_days: boolean;
    no_expiry: boolean;
    features: Record<string, unknown>;
  } | null;
}

interface StreakMilestone {
  days: number;
  reward_points: number;
  reward_xp: number;
  message?: string;
  box_id?: string;
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

  const authHeader = req.headers.get("authorization") ?? "";
  if (!authHeader.includes(serviceRoleKey)) {
    return new Response(JSON.stringify({ error: "غير مصرح — يتطلب service_role" }), {
      status: 401,
      headers: JSON_HEADERS,
    });
  }

  const svc = createClient(supabaseUrl, serviceRoleKey);

  try {
    // 1. Fetch global settings from key-value table
    const { data: settingRows } = await svc
      .from("subscription_settings")
      .select("key, value")
      .in("key", [
        "active_day_min_rides",
        "active_day_min_hours",
        "active_day_min_revenue_etb",
        "inactive_xp_penalty_per_day",
        "inactive_level_decay_days",
        "personal_goal_window_days",
        "personal_goal_multiplier",
      ]);

    const settings: Record<string, number> = {};
    for (const row of (settingRows ?? [])) {
      const raw = row.value;
      // value may be stored as JSON number/string or quoted string
      const parsed = typeof raw === "number"
        ? raw
        : parseFloat(String(raw).replace(/^"|"$/g, ""));
      if (!isNaN(parsed)) settings[row.key as string] = parsed;
    }

    const minRides          = settings.active_day_min_rides           ?? 3;
    const minHours          = settings.active_day_min_hours            ?? 2;
    const minRevenue        = settings.active_day_min_revenue_etb      ?? 0;
    const inactiveXpPenalty = settings.inactive_xp_penalty_per_day    ?? 10;
    const decayDays         = settings.inactive_level_decay_days       ?? 30;
    const goalWindowDays    = settings.personal_goal_window_days       ?? 14;
    const goalMultiplier    = settings.personal_goal_multiplier        ?? 1.25;

    // 2. Fetch streak milestone config (milestones is a JSONB array in streak_configs)
    const { data: streakConfigRow } = await svc
      .from("streak_configs")
      .select("min_rides, milestones")
      .eq("period_type", "daily")
      .maybeSingle();

    const milestones: StreakMilestone[] =
      (streakConfigRow?.milestones as StreakMilestone[]) ?? [];

    // 3. Fetch all active, non-frozen subscriptions with plan details
    const { data: activeSubs, error: subsErr } = await svc
      .from("driver_subscriptions")
      .select(`
        id,
        driver_id,
        ends_at,
        active_days_used,
        active_days_quota,
        subscription_plans (
          use_active_days,
          no_expiry,
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

    console.log(JSON.stringify({ fn: "process-active-days", event: "start", date: yesterdayStr, drivers: (activeSubs as unknown[]).length }));

    // 4. Process each driver
    for (const sub of (activeSubs as unknown as DriverSubscription[]) ?? []) {
      try {
        const driverId = sub.driver_id;
        const plan     = sub.subscription_plans;
        const noExpiry = plan?.no_expiry ?? false;

        // ── Trial / calendar plan ────────────────────────────────
        if (!plan?.use_active_days) {
          if (sub.ends_at && !noExpiry && new Date(sub.ends_at) <= now) {
            await svc.from("driver_subscriptions")
              .update({ status: "expired" })
              .eq("id", sub.id);
          }
          processed++;
          continue;
        }

        // ── Active days plan ─────────────────────────────────────

        // Read yesterday's summary from driver_activity_days (updated by DB trigger)
        const { data: activityRow } = await svc
          .from("driver_activity_days")
          .select("rides_count, income_etb")
          .eq("driver_id", driverId)
          .eq("activity_date", yesterdayStr)
          .maybeSingle();

        const ridesYesterday  = activityRow?.rides_count  ?? 0;
        const incomeYesterday = Number(activityRow?.income_etb ?? 0);

        // Proxy for active hours until driver_activity_sessions tracking exists:
        // 0.4 h/ride ≈ 24 min average trip + wait time.
        const estimatedHours = ridesYesterday * 0.4;

        const wasActive =
          ridesYesterday >= minRides &&
          estimatedHours >= minHours &&
          (minRevenue <= 0 || incomeYesterday >= minRevenue);

        // Fetch current streak (last_active_date lives in driver_streaks)
        const { data: streakRow } = await svc
          .from("driver_streaks")
          .select("current_streak, longest_streak, last_active_date, streak_frozen")
          .eq("driver_id", driverId)
          .maybeSingle();

        const streakFrozen      = (streakRow?.streak_frozen as boolean)      ?? false;
        const currentStreak     = (streakRow?.current_streak as number)      ?? 0;
        const longestStreak     = (streakRow?.longest_streak as number)      ?? 0;
        const lastActiveDateStr = streakRow?.last_active_date as string | null;

        if (wasActive) {
          // ── Active day ─────────────────────────────────────────
          activeDaysCounted++;
          console.log(JSON.stringify({ fn: "process-active-days", event: "active_day", driver_id: driverId, rides: ridesYesterday }));

          const newActiveDaysUsed = (sub.active_days_used ?? 0) + 1;
          const subUpdate: Record<string, unknown> = {
            active_days_used: newActiveDaysUsed,
          };

          // Expire if quota reached (flex/no_expiry plans never expire this way)
          if (
            sub.active_days_quota !== null &&
            newActiveDaysUsed >= sub.active_days_quota &&
            !noExpiry
          ) {
            subUpdate.status = "expired";
          }

          await svc.from("driver_subscriptions").update(subUpdate).eq("id", sub.id);

          // Mark activity day as qualified
          await svc
            .from("driver_activity_days")
            .update({ qualified: true })
            .eq("driver_id", driverId)
            .eq("activity_date", yesterdayStr);

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

            // Sync best_streak to lifetime_stats
            if (newLongest > longestStreak) {
              await svc.from("driver_lifetime_stats").upsert(
                { driver_id: driverId, best_streak: newLongest },
                { onConflict: "driver_id", ignoreDuplicates: false }
              );
            }

            // Clear dormant flag if driver becomes active again
            await svc
              .from("driver_level_state")
              .update({ is_dormant: false, dormant_since: null })
              .eq("driver_id", driverId)
              .eq("is_dormant", true);

            // Check streak milestones
            for (const milestone of milestones) {
              if (newStreak === milestone.days) {
                if ((milestone.reward_points ?? 0) > 0) {
                  // Atomic points update — no race condition
                  await svc.rpc("increment_driver_points", {
                    p_driver_id: driverId,
                    p_amount:    milestone.reward_points,
                  });

                  await svc.from("points_transactions").insert({
                    user_id:     driverId,
                    amount:      milestone.reward_points,
                    type:        "bonus",
                    description: milestone.message || `مكافأة ${milestone.days} يوم متتالي`,
                  });
                }

                if ((milestone.reward_xp ?? 0) > 0) {
                  await svc.from("driver_xp_transactions").insert({
                    driver_id:   driverId,
                    amount:      milestone.reward_xp,
                    type:        "streak_milestone",
                    description: milestone.message || `XP ${milestone.days} يوم متتالي`,
                  });
                }
              }
            }
          }

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
            await svc.from("driver_streaks")
              .update({ current_streak: 0 })
              .eq("driver_id", driverId);
          }

          // XP penalty
          if (inactiveXpPenalty > 0) {
            await svc.from("driver_xp_transactions").insert({
              driver_id:   driverId,
              amount:      -inactiveXpPenalty,
              type:        "penalty_inactive",
              description: "خصم XP — يوم خمول",
            });
          }

          notifications.push({
            user_id: driverId,
            title:   "يوم هادئ",
            body:    "لم يُحتسب اليوم من رصيدك — حاول إكمال المزيد من الرحلات",
            type:    "inactive_day",
          });
        }

        // ── Dormant check (replaces hard level-down) ──────────────
        const decayThreshold = new Date(now);
        decayThreshold.setUTCDate(decayThreshold.getUTCDate() - decayDays);
        const lastActivityDate = lastActiveDateStr ? new Date(lastActiveDateStr) : null;

        if (!lastActivityDate || lastActivityDate < decayThreshold) {
          await svc
            .from("driver_level_state")
            .update({ is_dormant: true, dormant_since: toDateString(now) })
            .eq("driver_id", driverId)
            .is("dormant_since", null); // only set once
        }

        // ── Update personal ride goal ──────────────────────────
        const goalWindowStart = new Date(now);
        goalWindowStart.setUTCDate(goalWindowStart.getUTCDate() - goalWindowDays);
        const goalWindowStartStr = toDateString(goalWindowStart);

        const { data: recentDays } = await svc
          .from("driver_activity_days")
          .select("rides_count")
          .eq("driver_id", driverId)
          .gte("activity_date", goalWindowStartStr);

        if (recentDays && recentDays.length > 0) {
          const totalRides     = recentDays.reduce((a, r) => a + (r.rides_count as number), 0);
          const avgRidesPerDay = totalRides / goalWindowDays; // use full window, not just active days
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

    console.log(JSON.stringify({ fn: "process-active-days", event: "done", processed, active_days_counted: activeDaysCounted, errors: errors.length }));

    // 5. Fire notifications (non-blocking)
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
