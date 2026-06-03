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
    // Body is optional
  }

  try {
    const driverId = user.id;

    // 1. Fetch subscription settings
    const { data: settings } = await svc
      .from("subscription_settings")
      .select("freeze_max_times_per_month, freeze_min_days")
      .single();

    const freezeMaxPerMonth: number = (settings?.freeze_max_times_per_month as number) ?? 2;
    const freezeMinDays: number     = (settings?.freeze_min_days as number) ?? 3;

    // 2. Find active, non-frozen subscription
    const { data: subscription, error: subErr } = await svc
      .from("driver_subscriptions")
      .select("id, ends_at, is_frozen, freeze_count_month, freeze_month_reset_at, active_days_quota, active_days_used, no_expiry, plan_id, subscription_plans(features)")
      .eq("driver_id", driverId)
      .eq("status", "active")
      .eq("is_frozen", false)
      .maybeSingle();

    if (subErr) {
      return new Response(JSON.stringify({ error: "خطأ في جلب بيانات الاشتراك", details: subErr.message }), {
        status: 500,
        headers: JSON_HEADERS,
      });
    }

    if (!subscription) {
      return new Response(JSON.stringify({ error: "لا يوجد اشتراك نشط قابل للتجميد" }), {
        status: 400,
        headers: JSON_HEADERS,
      });
    }

    // 3. Check monthly freeze quota — reset if needed
    const monthStart = new Date();
    monthStart.setUTCDate(1);
    monthStart.setUTCHours(0, 0, 0, 0);

    let freezeCountMonth: number = (subscription.freeze_count_month as number) ?? 0;
    const resetAt = subscription.freeze_month_reset_at
      ? new Date(subscription.freeze_month_reset_at as string)
      : null;

    if (!resetAt || resetAt < monthStart) {
      // Reset counter for new month
      freezeCountMonth = 0;
    }

    if (freezeCountMonth >= freezeMaxPerMonth) {
      return new Response(
        JSON.stringify({ error: `لقد وصلت إلى الحد الأقصى للتجميد هذا الشهر (${freezeMaxPerMonth} مرات)` }),
        { status: 400, headers: JSON_HEADERS }
      );
    }

    // 4. Check remaining days >= freeze_min_days
    if (subscription.ends_at) {
      const remainingMs = new Date(subscription.ends_at as string).getTime() - Date.now();
      const remainingDays = remainingMs / (1000 * 60 * 60 * 24);
      if (remainingDays < freezeMinDays) {
        return new Response(
          JSON.stringify({ error: `يجب أن تكون المدة المتبقية ${freezeMinDays} أيام على الأقل للتجميد` }),
          { status: 400, headers: JSON_HEADERS }
        );
      }
    }

    const frozenAt = new Date().toISOString();

    // 5. Insert subscription_freezes record
    const { error: freezeInsertErr } = await svc
      .from("subscription_freezes")
      .insert({
        driver_id:      driverId,
        subscription_id: subscription.id,
        reason_id:      body.reason_id ?? null,
        custom_reason:  body.custom_reason ?? null,
        frozen_at:      frozenAt,
      });

    if (freezeInsertErr) {
      return new Response(
        JSON.stringify({ error: "فشل في إنشاء سجل التجميد", details: freezeInsertErr.message }),
        { status: 500, headers: JSON_HEADERS }
      );
    }

    // 6. Update driver_subscriptions
    await svc
      .from("driver_subscriptions")
      .update({
        is_frozen:              true,
        freeze_count_month:     freezeCountMonth + 1,
        freeze_month_reset_at:  monthStart.toISOString(),
      })
      .eq("id", subscription.id);

    // 7. Freeze streak
    await svc
      .from("driver_streaks")
      .update({ streak_frozen: true, streak_frozen_at: frozenAt })
      .eq("driver_id", driverId);

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
