// =============================================================
// Edge Function: check-achievements
// Checks and unlocks achievements for a driver after events.
// Auth: service_role only (called internally).
// Supports scope filtering: 'ride' | 'streak' | 'rating' | 'any'
// =============================================================
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const JSON_HEADERS = { ...CORS_HEADERS, "Content-Type": "application/json" };

/** Returns the period key string for repeatable achievements */
function getPeriodKey(periodType: string): string {
  const now = new Date();
  if (periodType === "monthly") {
    return `${now.getUTCFullYear()}-${String(now.getUTCMonth() + 1).padStart(2, "0")}`;
  }
  if (periodType === "weekly") {
    const startOfYear = new Date(Date.UTC(now.getUTCFullYear(), 0, 1));
    const week = Math.ceil(
      ((now.getTime() - startOfYear.getTime()) / 86400000 + startOfYear.getUTCDay() + 1) / 7
    );
    return `${now.getUTCFullYear()}-W${String(week).padStart(2, "0")}`;
  }
  return now.toISOString().slice(0, 10);
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

  let body: { driver_id: string; ride_id?: string; scope?: string };
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "جسم الطلب غير صالح" }), {
      status: 400,
      headers: JSON_HEADERS,
    });
  }

  if (!body.driver_id) {
    return new Response(JSON.stringify({ error: "driver_id مطلوب" }), {
      status: 400,
      headers: JSON_HEADERS,
    });
  }

  const svc      = createClient(supabaseUrl, serviceRoleKey);
  const driverId = body.driver_id;
  const scope    = body.scope ?? "any"; // 'ride' | 'streak' | 'rating' | 'any'

  try {
    // 1. Fetch active achievements filtered by evaluation_scope
    const achQuery = svc
      .from("achievements")
      .select("*")
      .eq("is_active", true);

    // Filter by scope: include 'any' achievements always; scope-specific only when relevant
    if (scope !== "any") {
      achQuery.or(`evaluation_scope.eq.any,evaluation_scope.eq.${scope}`);
    }

    const { data: achievements, error: achErr } = await achQuery;

    if (achErr || !achievements) {
      return new Response(
        JSON.stringify({ error: "فشل جلب الإنجازات", details: achErr?.message }),
        { status: 500, headers: JSON_HEADERS }
      );
    }

    // 2. Pre-fetch driver state in parallel
    const [
      { data: lifetimeStats },
      { data: streakRow },
      { data: profile },
    ] = await Promise.all([
      svc.from("driver_lifetime_stats").select("*").eq("driver_id", driverId).maybeSingle(),
      svc.from("driver_streaks").select("current_streak").eq("driver_id", driverId).maybeSingle(),
      svc.from("profiles").select("id, fcm_token, points").eq("id", driverId).maybeSingle(),
    ]);

    const rideCount     = (lifetimeStats?.total_rides as number) ?? 0;
    const totalXp       = (lifetimeStats?.total_xp_earned as number) ?? 0;
    const total5Star    = (lifetimeStats?.total_5star_rides as number) ?? 0;
    const currentStreak = (streakRow?.current_streak as number) ?? 0;

    // 3. Compute average rating only for rating achievements
    // Query ratings table (score column, rated_user = driver)
    let ratingAvg: number | null = null;
    const hasRatingAchievement   = achievements.some((a) => a.trigger_type === "rating_avg");

    if (hasRatingAchievement && rideCount >= 10) {
      // Fast path: if 85%+ are 5-star, do precise query
      if (rideCount > 0 && total5Star / rideCount >= 0.85) {
        const { data: ratingData } = await svc
          .from("ratings")
          .select("score")
          .eq("rated_user", driverId)
          .not("score", "is", null);

        if (ratingData && ratingData.length > 0) {
          const sum = ratingData.reduce(
            (acc: number, r: Record<string, unknown>) => acc + (r.score as number),
            0
          );
          ratingAvg = sum / ratingData.length;
        }
      }
    }

    const unlockedIds: string[] = [];
    const notifications: Array<{ user_id: string; title: string; body: string; type: string }> = [];

    // 4. Check each achievement
    for (const ach of achievements) {
      if (ach.trigger_type === "admin_manual") continue;

      const periodKey = ach.is_repeatable && ach.period_type
        ? getPeriodKey(ach.period_type as string)
        : null;

      // Check if already earned
      const earnedQuery = svc
        .from("driver_achievements")
        .select("id")
        .eq("driver_id", driverId)
        .eq("achievement_id", ach.id);

      if (periodKey) {
        earnedQuery.eq("period_key", periodKey);
      } else {
        earnedQuery.is("period_key", null);
      }

      const { data: existing } = await earnedQuery.maybeSingle();
      if (existing) continue;

      // Check trigger condition
      let conditionMet = false;

      switch (ach.trigger_type) {
        case "ride_count":
          conditionMet = rideCount >= (ach.trigger_value as number);
          break;
        case "streak_days":
          conditionMet = currentStreak >= (ach.trigger_value as number);
          break;
        case "xp_total":
          conditionMet = totalXp >= (ach.trigger_value as number);
          break;
        case "rating_avg":
          conditionMet = ratingAvg !== null && ratingAvg >= (ach.trigger_value as number);
          break;
        default:
          conditionMet = false;
      }

      if (!conditionMet) continue;

      // 5. Unlock achievement
      const { error: insertErr } = await svc.from("driver_achievements").insert({
        driver_id:      driverId,
        achievement_id: ach.id,
        period_key:     periodKey ?? null,
        earned_at:      new Date().toISOString(),
      });

      if (insertErr) {
        console.error(`Failed to insert achievement ${ach.id}:`, insertErr.message);
        continue;
      }

      unlockedIds.push(ach.id as string);
      console.log(JSON.stringify({ fn: "check-achievements", event: "achievement_unlocked", driver_id: driverId, achievement_id: ach.id, name: ach.name_ar }));

      // Award reward points — atomic RPC (no race condition)
      if (ach.reward_points && (ach.reward_points as number) > 0) {
        await svc.rpc("increment_driver_points", {
          p_driver_id: driverId,
          p_amount:    ach.reward_points,
        });

        await svc.from("points_transactions").insert({
          user_id:     driverId,
          amount:      ach.reward_points,
          type:        "bonus",
          description: `مكافأة إنجاز: ${ach.name_ar}`,
        });
      }

      // Award XP
      if (ach.reward_xp && (ach.reward_xp as number) > 0) {
        await svc.from("driver_xp_transactions").insert({
          driver_id:   driverId,
          amount:      ach.reward_xp,
          type:        "achievement",
          description: `XP إنجاز: ${ach.name_ar}`,
        });
      }

      // Queue notification
      if (profile?.fcm_token) {
        notifications.push({
          user_id: driverId,
          title:   "إنجاز جديد! 🏆",
          body:    ach.name_ar as string,
          type:    "achievement",
        });
      }
    }

    // 6. Fire notifications (non-blocking)
    for (const notif of notifications) {
      fetch(`${supabaseUrl}/functions/v1/send-notification`, {
        method:  "POST",
        headers: {
          "Content-Type":  "application/json",
          "Authorization": `Bearer ${serviceRoleKey}`,
        },
        body: JSON.stringify(notif),
      }).catch((e) => console.warn("send-notification fire-and-forget failed:", e));
    }

    return new Response(
      JSON.stringify({ success: true, unlocked: unlockedIds }),
      { status: 200, headers: JSON_HEADERS }
    );
  } catch (err) {
    console.error("check-achievements error:", err);
    return new Response(
      JSON.stringify({ error: "خطأ داخلي في الخادم", details: String(err) }),
      { status: 500, headers: JSON_HEADERS }
    );
  }
});
