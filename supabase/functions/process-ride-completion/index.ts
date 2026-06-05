// =============================================================
// Edge Function: process-ride-completion
// Calculates and awards points + XP to a driver after a ride
// is marked completed. Called by service_role or admin only.
// =============================================================
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const JSON_HEADERS = { ...CORS_HEADERS, "Content-Type": "application/json" };

// Helper: check if a completed_at timestamp falls within a peak-hour time slot
function isPeakHour(
  completedAt: string,
  peakSlots: Array<{ start_time: string; end_time: string; days_of_week?: number[] }>
): boolean {
  const date   = new Date(completedAt);
  const dowJs  = date.getUTCDay(); // 0=Sun…6=Sat
  const hhmm   = date.getUTCHours() * 60 + date.getUTCMinutes();

  for (const slot of peakSlots) {
    if (slot.days_of_week && slot.days_of_week.length > 0) {
      if (!slot.days_of_week.includes(dowJs)) continue;
    }
    const [sh, sm] = slot.start_time.split(":").map(Number);
    const [eh, em] = slot.end_time.split(":").map(Number);
    const start    = sh * 60 + sm;
    const end      = eh * 60 + em;
    if (end > start) {
      if (hhmm >= start && hhmm < end) return true;
    } else {
      // overnight slot e.g. 22:00 – 02:00
      if (hhmm >= start || hhmm < end) return true;
    }
  }
  return false;
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

  // Auth: service_role key or admin JWT
  const authHeader = req.headers.get("authorization") ?? "";
  if (!authHeader.includes(serviceRoleKey)) {
    const anonKey    = Deno.env.get("SUPABASE_ANON_KEY")!;
    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user } } = await userClient.auth.getUser();
    if (!user) {
      return new Response(JSON.stringify({ error: "غير مصرح" }), {
        status: 401,
        headers: JSON_HEADERS,
      });
    }
    const svc              = createClient(supabaseUrl, serviceRoleKey);
    const { data: profile } = await svc.from("profiles").select("role").eq("id", user.id).single();
    if (!profile || profile.role !== "admin") {
      return new Response(JSON.stringify({ error: "غير مصرح — يتطلب صلاحيات المشرف" }), {
        status: 403,
        headers: JSON_HEADERS,
      });
    }
  }

  let body: { ride_id: string };
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "جسم الطلب غير صالح" }), {
      status: 400,
      headers: JSON_HEADERS,
    });
  }

  if (!body.ride_id) {
    return new Response(JSON.stringify({ error: "ride_id مطلوب" }), {
      status: 400,
      headers: JSON_HEADERS,
    });
  }

  const svc = createClient(supabaseUrl, serviceRoleKey);

  try {
    console.log(JSON.stringify({ fn: "process-ride-completion", event: "start", ride_id: body.ride_id }));

    // 1. Fetch ride — use actual column names from rides table
    const { data: ride, error: rideErr } = await svc
      .from("rides")
      .select("id, driver_id, passenger_id, distance_km, final_price, payment_method, status, completed_at")
      .eq("id", body.ride_id)
      .single();

    if (rideErr || !ride) {
      return new Response(JSON.stringify({ error: "الرحلة غير موجودة", details: rideErr?.message }), {
        status: 404,
        headers: JSON_HEADERS,
      });
    }

    if (ride.status !== "completed") {
      return new Response(JSON.stringify({ error: "الرحلة لم تكتمل بعد" }), {
        status: 400,
        headers: JSON_HEADERS,
      });
    }

    // 2. Fetch driver rating from ratings table (score is the rating column)
    const { data: ratingRow } = await svc
      .from("ratings")
      .select("score")
      .eq("ride_id", ride.id)
      .eq("rated_user", ride.driver_id)
      .maybeSingle();

    const driverRating = ratingRow?.score as number | null;

    // 3. Fetch active point earning rules
    const now = new Date().toISOString();
    const { data: pointRules } = await svc
      .from("point_earning_rules")
      .select("*")
      .eq("is_active", true)
      .or(`valid_from.is.null,valid_from.lte.${now}`)
      .or(`valid_until.is.null,valid_until.gte.${now}`)
      .order("sort_order");

    // 4. Fetch driver's vehicle type (column is "type", not "vehicle_type")
    const { data: vehicleRow } = await svc
      .from("vehicles")
      .select("type")
      .eq("driver_id", ride.driver_id)
      .eq("is_active", true)
      .maybeSingle();

    const vehicleType = vehicleRow?.type as string ?? "sedan";

    // 5. Fetch XP multiplier from active subscription plan
    const { data: activeSub } = await svc
      .from("driver_subscriptions")
      .select("subscription_plans(features)")
      .eq("driver_id", ride.driver_id)
      .eq("status", "active")
      .maybeSingle();

    const subscriptionFeatures =
      (activeSub?.subscription_plans as Record<string, unknown>)?.features as Record<string, unknown> ?? {};
    const xpMultiplier = (subscriptionFeatures.xp_multiplier as number) ?? 1.0;

    // 6. Calculate reward points for driver
    let rewardPoints = 0;

    for (const rule of (pointRules ?? [])) {
      switch (rule.rule_type) {
        case "per_ride":
          rewardPoints += rule.points_value;
          break;

        case "per_km":
          if (
            ride.distance_km != null &&
            (rule.min_threshold == null || ride.distance_km >= rule.min_threshold)
          ) {
            rewardPoints += rule.points_value * (ride.distance_km as number);
          }
          break;

        case "per_etb":
          if (ride.final_price != null) {
            rewardPoints += rule.points_value * (ride.final_price as number);
          }
          break;

        case "rating_bonus":
          if (
            driverRating != null &&
            rule.rating_threshold != null &&
            driverRating >= rule.rating_threshold
          ) {
            rewardPoints += rule.points_value;
          }
          break;

        case "peak_hour":
          if (ride.completed_at) {
            // time_range stores {"time_slots":[{start_time,end_time,days_of_week},...]}
            const slots = (
              (rule.time_range as Record<string, unknown>)?.time_slots as Array<{
                start_time: string;
                end_time: string;
                days_of_week?: number[];
              }>
            ) ?? [];
            if (isPeakHour(ride.completed_at as string, slots)) {
              rewardPoints += rule.points_value;
            }
          }
          break;
      }
    }

    // 7. Apply vehicle type multiplier (use first rule's vehicle_multipliers as global config)
    const vehicleMultipliers =
      (pointRules?.find((r) => r.vehicle_multipliers)?.vehicle_multipliers as Record<string, number>) ?? {};
    const vehicleMultiplier = vehicleMultipliers[vehicleType] ?? 1.0;
    rewardPoints = Math.floor(rewardPoints * vehicleMultiplier);

    // 8. Award points atomically (RPC avoids SELECT+UPDATE race condition)
    if (rewardPoints > 0) {
      await svc.rpc("increment_driver_points", {
        p_driver_id: ride.driver_id,
        p_amount:    rewardPoints,
      });

      await svc.from("points_transactions").insert({
        user_id:     ride.driver_id,
        amount:      rewardPoints,
        type:        "earned",
        description: "مكافآت رحلة مكتملة",
        ride_id:     ride.id,
      });
    }

    // 9. Calculate XP for driver
    const { data: xpRules } = await svc
      .from("xp_earning_rules")
      .select("*")
      .eq("is_active", true);

    let xpGained = 0;
    for (const xpRule of (xpRules ?? [])) {
      switch (xpRule.rule_type) {
        case "per_ride":
          xpGained += xpRule.xp_value;
          break;

        case "rating_bonus": {
          const condData  = (xpRule.condition_data as Record<string, number>) ?? {};
          const minRating = condData.min_rating;
          const maxRating = condData.max_rating;
          if (driverRating != null) {
            const meetsMin = minRating == null || driverRating >= minRating;
            const meetsMax = maxRating == null || driverRating <= maxRating;
            if (meetsMin && meetsMax) {
              xpGained += xpRule.xp_value;
            }
          }
          break;
        }
      }
    }

    // Apply subscription XP multiplier
    xpGained = Math.floor(xpGained * xpMultiplier);

    // 10. Record XP
    if (xpGained !== 0) {
      await svc.from("driver_xp_transactions").insert({
        driver_id:   ride.driver_id,
        amount:      xpGained,
        type:        "ride",
        description: "XP رحلة مكتملة",
        ride_id:     ride.id,
      });
    }

    // 11. Ensure required gamification rows exist for this driver
    const { data: levelDefBronze } = await svc
      .from("level_definitions")
      .select("id")
      .order("sort_order", { ascending: true })
      .limit(1)
      .single();

    await Promise.all([
      svc.from("driver_level_state").upsert(
        { driver_id: ride.driver_id, xp: 0, level_id: levelDefBronze?.id },
        { onConflict: "driver_id", ignoreDuplicates: true }
      ),
      svc.from("driver_streaks").upsert(
        { driver_id: ride.driver_id, current_streak: 0, longest_streak: 0 },
        { onConflict: "driver_id", ignoreDuplicates: true }
      ),
      svc.from("driver_goal_state").upsert(
        { driver_id: ride.driver_id, daily_goal_rides: 5 },
        { onConflict: "driver_id", ignoreDuplicates: true }
      ),
    ]);

    console.log(JSON.stringify({ fn: "process-ride-completion", event: "points_awarded", ride_id: ride.id, driver_id: ride.driver_id, reward_points: rewardPoints, xp: xpGained }));

    // 12. Fire check-achievements (non-blocking, scope=ride)
    fetch(`${supabaseUrl}/functions/v1/check-achievements`, {
      method:  "POST",
      headers: {
        "Content-Type":  "application/json",
        "Authorization": `Bearer ${serviceRoleKey}`,
      },
      body: JSON.stringify({ driver_id: ride.driver_id, ride_id: ride.id, scope: "ride" }),
    }).catch((e) => console.warn("check-achievements fire-and-forget failed:", e));

    return new Response(
      JSON.stringify({ success: true, reward_points: rewardPoints, xp: xpGained }),
      { status: 200, headers: JSON_HEADERS }
    );
  } catch (err) {
    console.error("process-ride-completion error:", err);
    return new Response(
      JSON.stringify({ error: "خطأ داخلي في الخادم", details: String(err) }),
      { status: 500, headers: JSON_HEADERS }
    );
  }
});
