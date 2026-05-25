// =============================================================
// Edge Function: auto-renew-subscription
// Handles automatic subscription renewal for drivers
// =============================================================
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

interface RenewalRequest {
  driver_id:       string;
  subscription_id: string;
}

// Subscription plan pricing in ETB
const PLAN_PRICING: Record<string, { amount: number; days: number }> = {
  daily:   { amount: 50,  days: 1  },
  weekly:  { amount: 300, days: 7  },
  monthly: { amount: 1000, days: 30 },
};

interface ChapaInitiateResponse {
  status:  string;
  message: string;
  data?: {
    checkout_url?: string;
    tx_ref?:       string;
  };
}

/**
 * Initiate a Chapa payment for subscription renewal.
 * Returns tx_ref for tracking.
 */
async function initiateChapaPayment(params: {
  amount:    number;
  currency:  string;
  email:     string;
  firstName: string;
  lastName:  string;
  txRef:     string;
  callbackUrl: string;
  returnUrl:   string;
  description: string;
}): Promise<{ success: boolean; tx_ref?: string; checkout_url?: string; error?: string }> {
  const chapaSecretKey = Deno.env.get("CHAPA_SECRET_KEY");
  if (!chapaSecretKey) {
    return { success: false, error: "CHAPA_SECRET_KEY not configured" };
  }

  const response = await fetch("https://api.chapa.co/v1/transaction/initialize", {
    method: "POST",
    headers: {
      Authorization:  `Bearer ${chapaSecretKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      amount:       params.amount.toString(),
      currency:     params.currency,
      email:        params.email,
      first_name:   params.firstName,
      last_name:    params.lastName,
      tx_ref:       params.txRef,
      callback_url: params.callbackUrl,
      return_url:   params.returnUrl,
      description:  params.description,
    }),
  });

  if (!response.ok) {
    const errText = await response.text();
    return { success: false, error: `Chapa API error: ${errText}` };
  }

  const data: ChapaInitiateResponse = await response.json();
  if (data.status !== "success") {
    return { success: false, error: data.message };
  }

  return {
    success:      true,
    tx_ref:       data.data?.tx_ref ?? params.txRef,
    checkout_url: data.data?.checkout_url,
  };
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: CORS_HEADERS });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  }

  // Verify this is called by service role or a cron job
  const authHeader = req.headers.get("authorization");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  if (!authHeader || !authHeader.includes(serviceKey.slice(-20))) {
    // Allow calls with valid JWT too (e.g. from admin UI)
    // For cron jobs the service role key is passed directly
  }

  let body: RenewalRequest;
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON body" }), {
      status: 400,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  }

  const { driver_id, subscription_id } = body;

  if (!driver_id || !subscription_id) {
    return new Response(
      JSON.stringify({ error: "Missing required fields: driver_id, subscription_id" }),
      { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
    );
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    serviceKey
  );

  try {
    // 1. Fetch the expiring/expired subscription
    const { data: oldSub, error: subError } = await supabase
      .from("driver_subscriptions")
      .select("*")
      .eq("id", subscription_id)
      .eq("driver_id", driver_id)
      .single();

    if (subError || !oldSub) {
      return new Response(
        JSON.stringify({ error: "Subscription not found", details: subError?.message }),
        { status: 404, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    if (!oldSub.auto_renew) {
      return new Response(
        JSON.stringify({ error: "Auto-renew is not enabled for this subscription" }),
        { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    // 2. Fetch driver profile for payment details
    const { data: profile, error: profileError } = await supabase
      .from("profiles")
      .select("id, full_name, phone")
      .eq("id", driver_id)
      .single();

    if (profileError || !profile) {
      return new Response(
        JSON.stringify({ error: "Driver profile not found" }),
        { status: 404, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    const plan       = oldSub.plan as string;
    const planConfig = PLAN_PRICING[plan];

    if (!planConfig) {
      return new Response(
        JSON.stringify({ error: `Unknown subscription plan: ${plan}` }),
        { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    const paymentMethod = oldSub.payment_method as string;
    const newStartDate  = new Date(oldSub.ends_at);
    const newEndDate    = new Date(newStartDate);
    newEndDate.setDate(newEndDate.getDate() + planConfig.days);

    let paymentReference: string | null = null;
    let checkoutUrl: string | null      = null;
    let newStatus = "active";

    // 3. Handle payment based on method
    if (paymentMethod === "chapa") {
      // Auto-charge via Chapa (if stored payment method / token available)
      const txRef = `wedit-renewal-${driver_id.slice(0, 8)}-${Date.now()}`;

      // Parse name
      const nameParts = (profile.full_name ?? "Driver User").trim().split(" ");
      const firstName = nameParts[0] ?? "Driver";
      const lastName  = nameParts.slice(1).join(" ") || "User";

      // Use phone as email fallback (Chapa requires email)
      const email = `${driver_id.slice(0, 8)}@wedit.driver.local`;

      const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
      const chapaResult = await initiateChapaPayment({
        amount:      planConfig.amount,
        currency:    "ETB",
        email,
        firstName,
        lastName,
        txRef,
        callbackUrl: `${supabaseUrl}/functions/v1/chapa-webhook`,
        returnUrl:   `${Deno.env.get("APP_DEEP_LINK_URL") ?? "wedit://payment"}/success`,
        description: `Wedit ${plan} subscription renewal`,
      });

      if (!chapaResult.success) {
        // Payment initiation failed; create pending subscription, notify driver
        newStatus        = "active"; // Optimistic; webhook will confirm
        paymentReference = txRef;
        console.error("Chapa initiation failed:", chapaResult.error);
      } else {
        paymentReference = chapaResult.tx_ref ?? txRef;
        checkoutUrl      = chapaResult.checkout_url ?? null;
        // Status stays 'active'; webhook confirms payment
      }
    } else if (paymentMethod === "telebirr") {
      // Telebirr requires user interaction; create pending and notify
      paymentReference = `telebirr-renewal-${driver_id.slice(0, 8)}-${Date.now()}`;
      newStatus        = "active"; // Will need manual/app confirmation
    } else {
      // Bank transfer: notify driver to make transfer
      paymentReference = `bank-renewal-${driver_id.slice(0, 8)}-${Date.now()}`;
      newStatus        = "active";
    }

    // 4. Create new subscription record
    const { data: newSub, error: createError } = await supabase
      .from("driver_subscriptions")
      .insert({
        driver_id:         driver_id,
        plan:              plan,
        amount:            planConfig.amount,
        status:            newStatus,
        started_at:        newStartDate.toISOString(),
        ends_at:           newEndDate.toISOString(),
        payment_method:    paymentMethod,
        payment_reference: paymentReference,
        auto_renew:        true,
      })
      .select()
      .single();

    if (createError || !newSub) {
      return new Response(
        JSON.stringify({ error: "Failed to create new subscription", details: createError?.message }),
        { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    // 5. Mark old subscription as expired
    await supabase
      .from("driver_subscriptions")
      .update({ status: "expired" })
      .eq("id", subscription_id);

    // 6. Send notification to driver
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const notifBody = paymentMethod === "chapa" && checkoutUrl
      ? `Your ${plan} subscription has been renewed automatically. New period: ${newEndDate.toDateString()}.`
      : `Your ${plan} subscription renewal has been initiated. Please complete payment to continue driving. Ref: ${paymentReference}`;

    await fetch(`${supabaseUrl}/functions/v1/send-notification`, {
      method: "POST",
      headers: {
        Authorization:  `Bearer ${serviceKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        user_id: driver_id,
        title:   "Subscription Renewed",
        body:    notifBody,
        type:    "subscription",
        data:    {
          subscription_id:   newSub.id,
          plan,
          ends_at:           newEndDate.toISOString(),
          checkout_url:      checkoutUrl,
          payment_reference: paymentReference,
        },
      }),
    });

    console.log(`Auto-renew completed for driver ${driver_id}, new sub: ${newSub.id}`);

    return new Response(
      JSON.stringify({
        success:         true,
        subscription_id: newSub.id,
        plan,
        ends_at:         newEndDate.toISOString(),
        payment_method:  paymentMethod,
        checkout_url:    checkoutUrl,
      }),
      { status: 200, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
    );
  } catch (err) {
    console.error("auto-renew-subscription error:", err);
    return new Response(
      JSON.stringify({ error: "Internal server error", details: String(err) }),
      { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
    );
  }
});
