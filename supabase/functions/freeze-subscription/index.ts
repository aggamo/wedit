// =============================================================
// Edge Function: freeze-subscription
// Allows a driver to freeze their active subscription.
// Auth: driver JWT required.
// =============================================================
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const JSON_HEADERS = { ...CORS_HEADERS, "Content-Type": "application/json" };

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
  const anonKey        = Deno.env.get("SUPABASE_ANON_KEY")!;

  const authHeader = req.headers.get("authorization") ?? "";
  if (!authHeader) {
    return new Response(JSON.stringify({ error: "مطلوب رمز التحقق" }), {
      status: 401,
      headers: JSON_HEADERS,
    });
  }

  // Authenticate driver
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

  let body: { reason_id?: string; custom_reason?: string } = {};
  try {
    body = await req.json();
  } catch {
    // body is optional
  }

  try {
    const driverId = user.id;

    // 1. Fetch subscription settings
    const { data: settingRows } = await svc
      .from("subscription_settings")
      .select("key, value")
      .in("key", ["freeze_max_times_per_month", "freeze_min_days"]);

    const settings: Record<string, number> = {};
    for (const row of (settingRows ?? [])) {
      const parsed = parseFloat(String(row.value).replace(/^"|"$/g, ""));
      if (!isNaN(parsed)) settings[row.key as string] = parsed;
    }

    const freezeMaxPerMonth = settings.freeze_max_times_per_month ?? 2;
    const freezeMinDays     = settings.freeze_min_days             ?? 1;

    // 2. Find active, non-frozen subscription
    const { data: subscription, error: subErr } = await svc
      .from("driver_subscriptions")
      .select("id, ends_at, is_frozen, active_days_quota, active_days_used, subscription_plan_id, subscription_plans(features, no_expiry)")
      .eq("driver_id", driverId)
      .eq("status", "active")
      .eq("is_frozen", false)
      .maybeSingle();

    if (subErr) {
      return new Response(
        JSON.stringify({ error: "خطأ في جلب بيانات الاشتراك", details: subErr.message }),
        { status: 500, headers: JSON_HEADERS }
      );
    }

    if (!subscription) {
      return new Response(JSON.stringify({ error: "لا يوجد اشتراك نشط قابل للتجميد" }), {
        status: 400,
        headers: JSON_HEADERS,
      });
    }

    // 3. Count freezes this month from subscription_freezes (no denormalized counter)
    const monthStart = new Date();
    monthStart.setUTCDate(1);
    monthStart.setUTCHours(0, 0, 0, 0);

    const { count: freezeCount, error: countErr } = await svc
      .from("subscription_freezes")
      .select("*", { count: "exact", head: true })
      .eq("driver_id", driverId)
      .gte("frozen_at", monthStart.toISOString());

    if (countErr) {
      return new Response(
        JSON.stringify({ error: "خطأ في التحقق من عدد التجميدات", details: countErr.message }),
        { status: 500, headers: JSON_HEADERS }
      );
    }

    if ((freezeCount ?? 0) >= freezeMaxPerMonth) {
      return new Response(
        JSON.stringify({
          error: `لقد وصلت إلى الحد الأقصى للتجميد هذا الشهر (${freezeMaxPerMonth} مرات)`,
        }),
        { status: 400, headers: JSON_HEADERS }
      );
    }

    // 4. Check remaining days (only for calendar-based plans with ends_at)
    const noExpiry =
      (subscription.subscription_plans as Record<string, unknown>)?.no_expiry as boolean ?? false;

    if (subscription.ends_at && !noExpiry) {
      const remainingMs   = new Date(subscription.ends_at as string).getTime() - Date.now();
      const remainingDays = remainingMs / (1000 * 60 * 60 * 24);
      if (remainingDays < freezeMinDays) {
        return new Response(
          JSON.stringify({
            error: `يجب أن تكون المدة المتبقية ${freezeMinDays} أيام على الأقل للتجميد`,
          }),
          { status: 400, headers: JSON_HEADERS }
        );
      }
    }

    const frozenAt = new Date().toISOString();

    // 5. Insert subscription_freezes record
    const { error: freezeInsertErr } = await svc.from("subscription_freezes").insert({
      driver_id:       driverId,
      subscription_id: subscription.id,
      reason_id:       body.reason_id    ?? null,
      custom_reason:   body.custom_reason ?? null,
      frozen_at:       frozenAt,
    });

    if (freezeInsertErr) {
      return new Response(
        JSON.stringify({ error: "فشل في إنشاء سجل التجميد", details: freezeInsertErr.message }),
        { status: 500, headers: JSON_HEADERS }
      );
    }

    // 6. Update driver_subscriptions (freeze_count columns removed in migration 018)
    await svc
      .from("driver_subscriptions")
      .update({ is_frozen: true })
      .eq("id", subscription.id);

    // 7. Freeze streak
    await svc
      .from("driver_streaks")
      .update({ streak_frozen: true, streak_frozen_at: frozenAt })
      .eq("driver_id", driverId);

    console.log(JSON.stringify({ fn: "freeze-subscription", event: "frozen", driver_id: driverId, subscription_id: subscription.id }));

    return new Response(
      JSON.stringify({ success: true, frozen_at: frozenAt }),
      { status: 200, headers: JSON_HEADERS }
    );
  } catch (err) {
    console.error("freeze-subscription error:", err);
    return new Response(
      JSON.stringify({ error: "خطأ داخلي في الخادم", details: String(err) }),
      { status: 500, headers: JSON_HEADERS }
    );
  }
});
