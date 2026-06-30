// =============================================================
// Edge Function: telebirr-webhook
// Handles Telebirr mobile payment webhook events
// =============================================================
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-telebirr-signature, x-telebirr-timestamp",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

interface TelebirrWebhookPayload {
  // Telebirr notification payload fields
  outTradeNo:     string;   // Our order/reference number
  tradeNo?:       string;   // Telebirr's own transaction number
  transactionNo?: string;   // Alternative field name used in some versions
  totalAmount?:   string;   // Amount as string
  tradeStatus?:   string;   // "SUCCESS" | "FAIL" | "PENDING"
  resultCode?:    string;   // "0" = success
  resultDesc?:    string;
  msisdn?:        string;   // Customer phone number
  [key: string]: unknown;
}

/**
 * Verify Telebirr webhook signature.
 * Telebirr uses HMAC-SHA256 or RSA depending on the version.
 * This implementation handles the HMAC variant.
 * Signature is typically: HMAC-SHA256(timestamp + body, secret)
 */
async function verifyTelebirrSignature(
  rawBody:   string,
  signature: string | null,
  timestamp: string | null,
  secret:    string
): Promise<boolean> {
  if (!signature || !timestamp) return false;

  try {
    const encoder = new TextEncoder();
    const keyData = encoder.encode(secret);
    const key = await crypto.subtle.importKey(
      "raw",
      keyData,
      { name: "HMAC", hash: "SHA-256" },
      false,
      ["sign"]
    );

    // Telebirr signs: timestamp + rawBody
    const data = encoder.encode(timestamp + rawBody);
    const sig  = await crypto.subtle.sign("HMAC", key, data);

    const computed = Array.from(new Uint8Array(sig))
      .map((b) => b.toString(16).padStart(2, "0"))
      .join("");

    // Normalise signature (remove any prefix)
    const incoming = signature.replace(/^(sha256=|hmac-sha256=)/i, "").toLowerCase();

    // Constant-time comparison
    if (computed.length !== incoming.length) return false;
    let diff = 0;
    for (let i = 0; i < computed.length; i++) {
      diff |= computed.charCodeAt(i) ^ incoming.charCodeAt(i);
    }
    return diff === 0;
  } catch (err) {
    console.error("Signature verification error:", err);
    return false;
  }
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

  const rawBody  = await req.text();
  const signature = req.headers.get("x-telebirr-signature");
  const timestamp = req.headers.get("x-telebirr-timestamp");
  const webhookSecret = Deno.env.get("TELEBIRR_WEBHOOK_SECRET");

  if (!webhookSecret) {
    console.error("TELEBIRR_WEBHOOK_SECRET env var not set");
    return new Response(JSON.stringify({ error: "Webhook secret not configured" }), {
      status: 500,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  }

  // Verify signature (skip in development mode if env var set)
  const skipSigVerify = Deno.env.get("TELEBIRR_SKIP_SIG_VERIFY") === "true";
  if (!skipSigVerify) {
    const valid = await verifyTelebirrSignature(rawBody, signature, timestamp, webhookSecret);
    if (!valid) {
      console.warn("Invalid Telebirr webhook signature");
      return new Response(JSON.stringify({ error: "Invalid signature" }), {
        status: 401,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }
  }

  let payload: TelebirrWebhookPayload;
  try {
    payload = JSON.parse(rawBody);
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON payload" }), {
      status: 400,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  }

  const outTradeNo = payload.outTradeNo;
  const tradeNo    = payload.tradeNo ?? payload.transactionNo;

  if (!outTradeNo) {
    return new Response(JSON.stringify({ error: "Missing outTradeNo in payload" }), {
      status: 400,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  }

  // Determine success/failure from Telebirr's result codes
  const isSuccess =
    payload.resultCode === "0" ||
    payload.tradeStatus === "SUCCESS";

  const internalStatus = isSuccess ? "completed" : "failed";

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  try {
    // Update payment record - try telebirr_tx_ref first, then reference
    let rideId:    string | null = null;
    let paymentId: string | null = null;

    const { data: payment, error: paymentError } = await supabase
      .from("payments")
      .update({
        status:         internalStatus,
        telebirr_tx_ref: tradeNo ?? outTradeNo,
      })
      .eq("telebirr_tx_ref", outTradeNo)
      .select("id, ride_id")
      .single();

    if (paymentError || !payment) {
      // Fallback: match by reference field
      const { data: paymentByRef, error: refError } = await supabase
        .from("payments")
        .update({
          status:          internalStatus,
          telebirr_tx_ref: tradeNo ?? outTradeNo,
        })
        .eq("reference", outTradeNo)
        .select("id, ride_id")
        .single();

      if (refError || !paymentByRef) {
        console.error("Payment not found for outTradeNo:", outTradeNo, paymentError, refError);
        // Return 200 so Telebirr doesn't retry for unknown references
        return new Response(
          JSON.stringify({ received: true, warning: "Payment record not found" }),
          { status: 200, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
        );
      }
      rideId    = paymentByRef.ride_id;
      paymentId = paymentByRef.id;
    } else {
      rideId    = payment.ride_id;
      paymentId = payment.id;
    }

    // Handle successful payment
    if (isSuccess && rideId && paymentId) {
      await handleSuccessfulTelebirrPayment(supabase, rideId, paymentId);
    }

    console.log(`Telebirr webhook processed: outTradeNo=${outTradeNo}, status=${internalStatus}`);

    // Telebirr expects a specific response format
    return new Response(
      JSON.stringify({
        code:    "0",
        message: "success",
        data:    { received: true, status: internalStatus },
      }),
      { status: 200, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
    );
  } catch (err) {
    console.error("Telebirr webhook processing error:", err);
    return new Response(
      JSON.stringify({ error: "Internal server error", details: String(err) }),
      { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
    );
  }
});

/**
 * Handle a successful Telebirr payment:
 * - Mark ride as completed
 * - Send completion notifications
 */
async function handleSuccessfulTelebirrPayment(
  supabase:  ReturnType<typeof createClient>,
  rideId:    string,
  paymentId: string
): Promise<void> {
  const { data: ride, error: rideError } = await supabase
    .from("rides")
    .select("id, passenger_id, driver_id, status, final_price")
    .eq("id", rideId)
    .single();

  if (rideError || !ride) {
    console.error("Failed to fetch ride:", rideError);
    return;
  }

  // Mark ride as completed if it was started
  if (ride.status === "started") {
    const { error: updateError } = await supabase
      .from("rides")
      .update({ status: "completed" })
      .eq("id", rideId);

    if (updateError) {
      console.error("Failed to complete ride:", updateError);
      return;
    }
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceKey  = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  // Notify passenger
  if (ride.passenger_id) {
    await fetch(`${supabaseUrl}/functions/v1/send-notification`, {
      method: "POST",
      headers: {
        Authorization:  `Bearer ${serviceKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        user_id: ride.passenger_id,
        title:   "Ride Completed",
        body:    `Your ride has been completed. Payment of ${ride.final_price ?? ""} ETB confirmed via Telebirr.`,
        type:    "ride_completed",
        data:    { ride_id: rideId, payment_id: paymentId },
      }),
    });
  }

  // Notify driver
  if (ride.driver_id) {
    await fetch(`${supabaseUrl}/functions/v1/send-notification`, {
      method: "POST",
      headers: {
        Authorization:  `Bearer ${serviceKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        user_id: ride.driver_id,
        title:   "Payment Received",
        body:    `Telebirr payment confirmed for your ride. Amount: ${ride.final_price ?? ""} ETB.`,
        type:    "payment",
        data:    { ride_id: rideId, payment_id: paymentId },
      }),
    });
  }
}
