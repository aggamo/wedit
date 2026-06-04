// =============================================================
// Edge Function: get-driver-gamification-summary
// Returns a complete snapshot of a driver's gamification state
// in a single call: subscription, level, XP, streak, points,
// pending boxes, recent achievements, goal, today's rides.
// Auth: driver JWT (own data) or admin JWT (any driver_id).
// =============================================================
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

const JSON_HEADERS = { ...CORS_HEADERS, "Content-Type": "application/json" };

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS_HEADERS });
  if (req.method !== "GET" && req.method !== "POST") {
    return new Response(JSON.stringify({ error: "الطريقة غير مسموح بها" }), {
      status: 405,
      headers: JSON_HEADERS,
    });
  }

  const supabaseUrl    = Deno.env.get("SUPABASE_URL")!;
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const anonKey        = Deno.env.get("SUPABASE_ANON_KEY")!;

  const authHeader = req.headers.get("authorization") ?? "";
  if (!authHeader) {
    return new Response(JSON.stringify({ error: "مطلوب رمز التحقق" }), {
      status: 401,
      headers: JSON_HEADERS,
    });
  }

  // Authenticate user
  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: { user }, error: authErr } = await userClient.auth.getUser();
  if (authErr || !user) {
    return new Response(JSON.stringify({ error: "غير مصرح" }), {
      status: 401,
      headers: JSON_HEADERS,
    });
  }

  const svc = createClient(supabaseUrl, serviceRoleKey);

  // Determine which driver to query
  let driverId = user.id;

  // Check if a specific driver_id was requested via query param or body
  const url = new URL(req.url);
  const queryDriverId = url.searchParams.get("driver_id");

  if (queryDriverId && queryDriverId !== user.id) {
    // Only admins can query other drivers
    const { data: profileRow } = await svc
      .from("profiles")
      .select("role")
      .eq("id", user.id)
      .single();

    if (!profileRow || profileRow.role !== "admin") {
      return new Response(JSON.stringify({ error: "غير مصرح — يتطلب صلاحيات المشرف لعرض بيانات سائق آخر" }), {
        status: 403,
        headers: JSON_HEADERS,
      });
    }

    driverId = queryDriverId;
  } else if (req.method === "POST") {
    try {
      const body = await req.json().catch(() => ({}));
      if (body.driver_id && body.driver_id !== user.id) {
        const { data: profileRow } = await svc
          .from("profiles")
          .select("role")
          .eq("id", user.id)
          .single();

        if (!profileRow || profileRow.role !== "admin") {
          return new Response(JSON.stringify({ error: "غير مصرح — يتطلب صلاحيات المشرف لعرض بيانات سائق آخر" }), {
            status: 403,
            headers: JSON_HEADERS,
          });
        }

        driverId = body.driver_id as string;
      }
    } catch {
      // No body or invalid JSON — use authenticated user's id
    }
  }

  try {
    const todayStr = new Date().toISOString().slice(0, 10);

    // Fetch all data in parallel for performance
    const [
      subResult,
      levelResult,
      streakResult,
      profileResult,
      pendingBoxesResult,
      recentAchievementsResult,
      goalResult,
      todayRidesResult,
      lifetimeStatsResult,
    ] = await Promise.all([
      // Subscription + plan details
      svc
        .from("driver_subscriptions")
        .select(`
          id,
          status,
          starts_at,
          ends_at,
          is_frozen,
          active_days_used,
          active_days_quota,
          frozen_days_total,
          freeze_count_month,
          no_expiry,
          subscription_plans (
            id,
            name_ar,
            use_active_days,
            features,
            price_etb
          )
        `)
        .eq("driver_id", driverId)
        .eq("status", "active")
        .maybeSingle(),

      // Level state + level definition + next level
      svc
        .from("driver_level_state")
        .select(`
          xp,
          level_id,
          level_definitions (
            id,
            level_key,
            name_ar,
            min_xp,
            max_xp,
            badge_icon,
            sort_order
          )
        `)
        .eq("driver_id", driverId)
        .maybeSingle(),

      // Streak
      svc
        .from("driver_streaks")
        .select("current_streak, longest_streak, last_active_date, streak_frozen, streak_frozen_at")
        .eq("driver_id", driverId)
        .maybeSingle(),

      // Profile (reward points, FCM)
      svc
        .from("profiles")
        .select("points, full_name")
        .eq("id", driverId)
        .single(),

      // Pending boxes count
      svc
        .from("driver_box_openings")
        .select("*", { count: "exact", head: true })
        .eq("driver_id", driverId)
        .eq("prize_delivered", false),

      // Recent achievements (last 5) with achievement details
      svc
        .from("driver_achievements")
        .select(`
          id,
          earned_at,
          period_key,
          achievements (
            id,
            name_ar,
            description_ar,
            icon,
            reward_points,
            reward_xp
          )
        `)
        .eq("driver_id", driverId)
        .order("earned_at", { ascending: false })
        .limit(5),

      // Personal ride goal
      svc
        .from("driver_goal_state")
        .select("daily_goal_rides, computed_at")
        .eq("driver_id", driverId)
        .maybeSingle(),

      // Today's completed rides
      svc
        .from("rides")
        .select("*", { count: "exact", head: true })
        .eq("driver_id", driverId)
        .eq("status", "completed")
        .gte("completed_at", `${todayStr}T00:00:00Z`)
        .lt("completed_at", `${todayStr}T23:59:59Z`),

      // Lifetime stats (denormalized totals)
      svc
        .from("driver_lifetime_stats")
        .select("total_rides, total_km, total_income_etb, total_xp_earned, best_streak, total_subscriptions, total_5star_rides")
        .eq("driver_id", driverId)
        .maybeSingle(),
    ]);

    // Calculate XP to next level
    const currentXp      = (levelResult.data?.xp as number) ?? 0;
    const currentLevelDef = levelResult.data?.level_definitions as Record<string, unknown> | null;
    const currentSortOrder = (currentLevelDef?.sort_order as number) ?? 0;

    let xpToNext: number | null = null;
    let nextLevel: Record<string, unknown> | null = null;

    if (currentLevelDef) {
      const { data: nextLevelDef } = await svc
        .from("level_definitions")
        .select("id, level_key, name_ar, min_xp, badge_icon")
        .gt("sort_order", currentSortOrder)
        .order("sort_order", { ascending: true })
        .limit(1)
        .maybeSingle();

      if (nextLevelDef) {
        nextLevel = nextLevelDef as Record<string, unknown>;
        xpToNext  = Math.max(0, (nextLevelDef.min_xp as number) - currentXp);
      }
    }

    // Build response
    const response = {
      subscription: subResult.data
        ? {
            id:                subResult.data.id,
            status:            subResult.data.status,
            starts_at:         subResult.data.starts_at,
            ends_at:           subResult.data.ends_at,
            is_frozen:         subResult.data.is_frozen,
            active_days_used:  subResult.data.active_days_used,
            active_days_quota: subResult.data.active_days_quota,
            frozen_days_total: subResult.data.frozen_days_total,
            freeze_count_month: subResult.data.freeze_count_month,
            no_expiry:         subResult.data.no_expiry,
            plan:              subResult.data.subscription_plans,
          }
        : null,

      level: currentLevelDef
        ? {
            ...currentLevelDef,
            current_xp: currentXp,
          }
        : null,

      xp_to_next:   xpToNext,
      next_level:   nextLevel,

      streak: streakResult.data
        ? {
            current_streak:    streakResult.data.current_streak,
            longest_streak:    streakResult.data.longest_streak,
            last_active_date:  streakResult.data.last_active_date,
            streak_frozen:     streakResult.data.streak_frozen,
            streak_frozen_at:  streakResult.data.streak_frozen_at,
          }
        : {
            current_streak:   0,
            longest_streak:   0,
            last_active_date: null,
            streak_frozen:    false,
            streak_frozen_at: null,
          },

      reward_points: (profileResult.data?.points as number) ?? 0,

      pending_boxes: pendingBoxesResult.count ?? 0,

      recent_achievements: (recentAchievementsResult.data ?? []).map((da: Record<string, unknown>) => ({
        id:             da.id,
        earned_at:      da.earned_at,
        period_key:     da.period_key,
        achievement:    da.achievements,
      })),

      goal: goalResult.data
        ? {
            daily_goal_rides: goalResult.data.daily_goal_rides,
            computed_at:      goalResult.data.computed_at,
          }
        : { daily_goal_rides: 5, computed_at: null },

      today_rides: todayRidesResult.count ?? 0,

      lifetime_stats: lifetimeStatsResult.data
        ? {
            total_rides:        lifetimeStatsResult.data.total_rides,
            total_km:           lifetimeStatsResult.data.total_km,
            total_income_etb:   lifetimeStatsResult.data.total_income_etb,
            total_xp_earned:    lifetimeStatsResult.data.total_xp_earned,
            best_streak:        lifetimeStatsResult.data.best_streak,
            total_subscriptions:lifetimeStatsResult.data.total_subscriptions,
            total_5star_rides:  lifetimeStatsResult.data.total_5star_rides,
          }
        : null,

      driver_name: profileResult.data?.full_name ?? null,
    };

    return new Response(
      JSON.stringify(response),
      { status: 200, headers: JSON_HEADERS }
    );
  } catch (err) {
    console.error("get-driver-gamification-summary error:", err);
    return new Response(
      JSON.stringify({ error: "خطأ داخلي في الخادم", details: String(err) }),
      { status: 500, headers: JSON_HEADERS }
    );
  }
});
