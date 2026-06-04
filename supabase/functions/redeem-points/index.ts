// =============================================================
// Edge Function: redeem-points
// Allows a driver to redeem their reward points for a
// configured redemption option (subscription days, XP, etc.)
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

  let body: { option_id: string };
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "جسم الطلب غير صالح" }), {
      status: 400,
      headers: JSON_HEADERS,
    });
  }

  if (!body.option_id) {
    return new Response(JSON.stringify({ error: "option_id مطلوب" }), {
      status: 400,
      headers: JSON_HEADERS,
    });
  }

  const svc      = createClient(supabaseUrl, serviceRoleKey);
  const driverId = user.id;

  try {
    // 1. Fetch redemption option
    const { data: option, error: optErr } = await svc
      .from("redemption_options")
      .select("id, name_ar, option_type, points_cost, value, valid_from, valid_until, is_active")
      .eq("id", body.option_id)
      .eq("is_active", true)
      .single();

    if (optErr || !option) {
      return new Response(JSON.stringify({ error: "خيار الاستبدال غير موجود أو غير نشط" }), {
        status: 404,
        headers: JSON_HEADERS,
      });
    }

    // 2. Validate date range
    const now = new Date();
    if (option.valid_from && new Date(option.valid_from as string) > now) {
      return new Response(JSON.stringify({ error: "خيار الاستبدال لم يبدأ بعد" }), {
        status: 400,
        headers: JSON_HEADERS,
      });
    }
    if (option.valid_until && new Date(option.valid_until as string) < now) {
      return new Response(JSON.stringify({ error: "انتهت صلاحية خيار الاستبدال" }), {
        status: 400,
        headers: JSON_HEADERS,
      });
    }

    // 3. Check driver's current points
    const { data: profileRow, error: profileErr } = await svc
      .from("profiles")
      .select("points")
      .eq("id", driverId)
      .single();

    if (profileErr || !profileRow) {
      return new Response(JSON.stringify({ error: "فشل جلب بيانات السائق" }), {
        status: 500,
        headers: JSON_HEADERS,
      });
    }

    const currentPoints: number = (profileRow.points as number) ?? 0;
    const pointsCost: number    = option.points_cost as number;

    if (currentPoints < pointsCost) {
      return new Response(JSON.stringify({ error: "رصيدك غير كافٍ للاستبدال" }), {
        status: 400,
        headers: JSON_HEADERS,
      });
    }

    // 4. Deduct points (atomic check)
    const { error: deductErr } = await svc
      .from("profiles")
      .update({ points: currentPoints - pointsCost })
      .eq("id", driverId)
      .gte("points", pointsCost); // guard against race condition

    if (deductErr) {
      return new Response(JSON.stringify({ error: "فشل خصم النقاط", details: deductErr.message }), {
        status: 500,
        headers: JSON_HEADERS,
      });
    }

    // 5. Record points transaction
    await svc.from("points_transactions").insert({
      user_id:     driverId,
      amount:      -pointsCost,
      type:        "redeemed",
      description: `استبدال: ${option.name_ar}`,
    });

    // 6. Determine redemption status and apply value
    let redemptionStatus = "completed";
    const optionType     = option.option_type as string;
    const optionValue    = option.value as number;

    switch (optionType) {
      case "subscription_days": {
        const { data: activeSub } = await svc
          .from("driver_subscriptions")
          .select("id, ends_at, no_expiry")
          .eq("driver_id", driverId)
          .eq("status", "active")
          .maybeSingle();

        if (activeSub && activeSub.ends_at && !activeSub.no_expiry) {
          const newEndsAt = new Date(activeSub.ends_at as string);
          newEndsAt.setUTCDate(newEndsAt.getUTCDate() + optionValue);
          await svc
            .from("driver_subscriptions")
            .update({ ends_at: newEndsAt.toISOString() })
            .eq("id", activeSub.id);
        }
        break;
      }
      case "freeze_days":
        // Recorded in driver_redemptions — admin processes freeze allowance
        redemptionStatus = "completed";
        break;
      case "priority_hours":
        // Recorded only — operational logic handled by dispatcher
        break;
      case "etb":
        // Manual disbursement required
        redemptionStatus = "pending";
        break;
      case "xp": {
        await svc.from("driver_xp_transactions").insert({
          driver_id:   driverId,
          amount:      optionValue,
          type:        "redemption",
          description: `XP مقابل استبدال: ${option.name_ar}`,
        });
        break;
      }
    }

    // 7. Record redemption
    await svc.from("driver_redemptions").insert({
      driver_id:      driverId,
      option_id:      option.id,
      points_spent:   pointsCost,
      value_received: optionValue,
      status:         redemptionStatus,
    });

    const newBalance = currentPoints - pointsCost;

    return new Response(
      JSON.stringify({
        success:     true,
        new_balance: newBalance,
        option_type: optionType,
        value:       optionValue,
        status:      redemptionStatus,
      }),
      { status: 200, headers: JSON_HEADERS }
    );
  } catch (err) {
    console.error("redeem-points error:", err);
    return new Response(
      JSON.stringify({ error: "خطأ داخلي في الخادم", details: String(err) }),
      { status: 500, headers: JSON_HEADERS }
    );
  }
});
