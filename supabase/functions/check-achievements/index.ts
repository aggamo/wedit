// =============================================================
// Edge Function: check-achievements
// Checks and unlocks achievements for a driver after events.
// Auth: service_role only (called internally).
// =============================================================
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const JSON_HEADERS = { ...CORS_HEADERS, "Content-Type": "application/json" };

/** Returns the period key string for repeatable achievements (e.g. "2026-06") */
function getPeriodKey(periodType: string): string {
  const now = new Date();
  if (periodType === "monthly") {
    return `${now.getUTCFullYear()}-${String(now.getUTCMonth() + 1).padStart(2, "0")}`;
  }
  if (periodType === "weekly") {
    // ISO week number
    const startOfYear = new Date(Date.UTC(now.getUTCFullYear(), 0, 1));
    const week = Math.ceil(((now.getTime() - startOfYear.getTime()) / 86400000 + startOfYear.getUTCDay() + 1) / 7);
    return `${now.getUTCFullYear()}-W${String(week).padStart(2, "0")}`;
  }
  // daily
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

  // Auth: service_role only
  const authHeader = req.headers.get("authorization") ?? "";
  if (!authHeader.includes(serviceRoleKey)) {
    return new Response(JSON.stringify({ error: "غير مصرح — يتطلب service_role" }), {
      status: 401,
      headers: JSON_HEADERS,
    });
  }

  let body: { driver_id: string; ride_id?: string };
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

  try {
    // 1. Fetch all active achievements
    const { data: achievements, error: achErr } = await svc
      .from("achievements")
      .select("*")
      .eq("is_active", true);

    if (achErr || !achievements) {
      return new Response(JSON.stringify({ error: "فشل جلب الإنجازات", details: achErr?.message }), {
        status: 500,
        headers: JSON_HEADERS,
      });
    }

    // Pre-fetch driver state once to avoid repeated queries
    const [
      { count: rideCount },
      { data: streakRow },
      { data: levelState },
      { data: profile },
    ] = await Promise.all([
      svc
        .from("rides")
        .select("*", { count: "exact", head: true })
        .eq("driver_id", driverId)
        .eq("status", "completed"),
      svc.from("driver_streaks").select("current_streak").eq("driver_id", driverId).maybeSingle(),
      svc.from("driver_level_state").select("xp").eq("driver_id", driverId).maybeSingle(),
      svc.from("profiles").select("id, fcm_token, points").eq("id", driverId).maybeSingle(),
    ]);

    // Fetch rating avg (only meaningful if >= 10 rides)
    let ratingAvg: number | null = null;
    if ((rideCount ?? 0) >= 10) {
      const { data: ratingData } = await svc
        .from("rides")
        .select("driver_rating")
        .eq("driver_id", driverId)
        .eq("status", "completed")
        .not("driver_rating", "is", null);

      if (ratingData && ratingData.length > 0) {
        const sum = ratingData.reduce((acc: number, r: Record<string, unknown>) => acc + (r.driver_rating as number), 0);
        ratingAvg = sum / ratingData.length;
      }
    }

    const unlockedIds: string[] = [];
    const notifications: Array<{ user_id: string; title: string; body: string; type: string }> = [];

    // 2. Check each achievement
    for (const ach of achievements) {
      if (ach.trigger_type === "admin_manual") continue;

      // Determine period key for repeatable achievements
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
      if (existing) continue; // already earned this period

      // Check trigger condition
      let conditionMet = false;

      switch (ach.trigger_type) {
        case "ride_count":
          conditionMet = (rideCount ?? 0) >= (ach.trigger_value as number);
          break;
        case "streak_days":
          conditionMet = ((streakRow?.current_streak as number) ?? 0) >= (ach.trigger_value as number);
          break;
        case "xp_total":
          conditionMet = ((levelState?.xp as number) ?? 0) >= (ach.trigger_value as number);
          break;
        case "rating_avg":
          conditionMet = ratingAvg !== null && ratingAvg >= (ach.trigger_value as number);
          break;
        default:
          conditionMet = false;
      }

      if (!conditionMet) continue;

      // 3. Unlock achievement
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

      // Award reward points
      if (ach.reward_points && (ach.reward_points as number) > 0) {
        const currentPoints = (profile?.points as number) ?? 0;
        await svc
          .from("profiles")
          .update({ points: currentPoints + (ach.reward_points as number) })
          .eq("id", driverId);

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

    // 4. Fire notifications (non-blocking)
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
