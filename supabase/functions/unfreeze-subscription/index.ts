// =============================================================
// Edge Function: unfreeze-subscription
// Allows a driver to unfreeze their subscription,
// extending the end date by the frozen duration.
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

  const svc      = createClient(supabaseUrl, serviceRoleKey);
  const driverId = user.id;

  try {
    // 1. Find active (unfrozen) freeze record
    const { data: freezeRecord, error: freezeErr } = await svc
      .from("subscription_freezes")
      .select("id, subscription_id, frozen_at")
      .eq("driver_id", driverId)
      .is("unfrozen_at", null)
      .maybeSingle();

    if (freezeErr) {
      return new Response(
        JSON.stringify({ error: "خطأ في جلب بيانات التجميد", details: freezeErr.message }),
        { status: 500, headers: JSON_HEADERS }
      );
    }

    if (!freezeRecord) {
      return new Response(JSON.stringify({ error: "لا يوجد اشتراك مجمد" }), {
        status: 400,
        headers: JSON_HEADERS,
      });
    }

    // 2. Calculate frozen days (ceiling)
    const frozenAt      = new Date(freezeRecord.frozen_at as string);
    const nowDate       = new Date();
    const secondsFrozen = (nowDate.getTime() - frozenAt.getTime()) / 1000;
    const frozenDays    = Math.ceil(secondsFrozen / 86400);

    const unfrozenAt = nowDate.toISOString();

    // 3. Mark freeze as resolved
    await svc
      .from("subscription_freezes")
      .update({ unfrozen_at: unfrozenAt })
      .eq("id", freezeRecord.id);

    // 4. Fetch subscription details
    const { data: subscription } = await svc
      .from("driver_subscriptions")
      .select("id, ends_at, frozen_days_total, no_expiry")
      .eq("id", freezeRecord.subscription_id)
      .single();

    const previousFrozenDays = (subscription?.frozen_days_total as number) ?? 0;
    const totalFrozenDays    = previousFrozenDays + frozenDays;

    let newEndsAt: string | null = null;

    if (subscription?.ends_at && !subscription.no_expiry) {
      // Extend end date by frozen duration
      const currentEndsAt = new Date(subscription.ends_at as string);
      currentEndsAt.setUTCDate(currentEndsAt.getUTCDate() + frozenDays);
      newEndsAt = currentEndsAt.toISOString();
    }

    // 5. Update driver_subscriptions
    const updatePayload: Record<string, unknown> = {
      is_frozen:         false,
      frozen_days_total: totalFrozenDays,
    };
    if (newEndsAt) updatePayload.ends_at = newEndsAt;

    await svc
      .from("driver_subscriptions")
      .update(updatePayload)
      .eq("id", freezeRecord.subscription_id);

    // 6. Unfreeze streak
    await svc
      .from("driver_streaks")
      .update({ streak_frozen: false })
      .eq("driver_id", driverId);

    return new Response(
      JSON.stringify({
        success:     true,
        frozen_days: frozenDays,
        new_ends_at: newEndsAt,
      }),
      { status: 200, headers: JSON_HEADERS }
    );
  } catch (err) {
    console.error("unfreeze-subscription error:", err);
    return new Response(
      JSON.stringify({ error: "خطأ داخلي في الخادم", details: String(err) }),
      { status: 500, headers: JSON_HEADERS }
    );
  }
});
