// =============================================================
// Edge Function: chapa-webhook
// Handles Chapa payment gateway webhook events
// =============================================================
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { createHmac } from "https://deno.land/std@0.168.0/node/crypto.ts";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-chapa-signature",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

interface ChapaWebhookPayload {
  event:     string;   // e.g. "charge.success"
  tx_ref:    string;   // transaction reference (our internal ref)
  status:    string;   // "success" | "failed"
  amount?:   number;
  currency?: string;
  [key: string]: unknown;
}

/**
 * Verify the Chapa HMAC-SHA256 webhook signature.
 * Chapa sends: x-chapa-signature: sha256=<hex_digest>
 */
function verifySignature(
  payload:   string,
  signature: string | null,
  secret:    string
): boolean {
  if (!signature) return false;

  // Remove "sha256=" prefix if present
  const sigHex = signature.startsWith("sha256=")
    ? signature.slice(7)
    : signature;

  const hmac     = createHmac("sha256", secret);
  hmac.update(payload);
  const computed = hmac.digest("hex");

  // Constant-time comparison to prevent timing attacks
  if (computed.length !== sigHex.length) return false;
  let diff = 0;
  for (let i = 0; i < computed.length; i++) {
    diff |= computed.charCodeAt(i) ^ sigHex.charCodeAt(i);
  }
  return diff === 0;
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

  const rawBody = await req.text();
  const signature = req.headers.get("x-chapa-signature");
  const webhookSecret = Deno.env.get("CHAPA_WEBHOOK_SECRET");

  if (!webhookSecret) {
    console.error("CHAPA_WEBHOOK_SECRET env var not set");
    return new Response(JSON.stringify({ error: "Webhook secret not configured" }), {
      status: 500,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  }

  // Verify signature
  if (!verifySignature(rawBody, signature, webhookSecret)) {
    console.warn("Invalid Chapa webhook signature");
    return new Response(JSON.stringify({ error: "Invalid signature" }), {
      status: 401,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  }

  let payload: ChapaWebhookPayload;
  try {
    payload = JSON.parse(rawBody);
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON payload" }), {
      status: 400,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  }

  const { tx_ref, status } = payload;

  if (!tx_ref) {
    return new Response(JSON.stringify({ error: "Missing tx_ref in payload" }), {
      status: 400,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  try {
    // Map Chapa status to internal status
    const internalStatus = status === "success" ? "completed" : "failed";

    // Update payment record
    const { data: payment, error: paymentError } = await supabase
      .from("payments")
      .update({
        status:       internalStatus,
        chapa_tx_ref: tx_ref,
      })
      .eq("chapa_tx_ref", tx_ref)
      .select("id, ride_id, amount")
      .single();

    if (paymentError || !payment) {
      // Try matching by reference field as fallback
      const { data: paymentByRef, error: refError } = await supabase
        .from("payments")
        .update({
          status:       internalStatus,
          chapa_tx_ref: tx_ref,
        })
        .eq("reference", tx_ref)
        .select("id, ride_id, amount")
        .single();

      if (refError || !paymentByRef) {
        console.error("Payment not found for tx_ref:", tx_ref, paymentError, refError);
        // Return 200 to prevent Chapa from retrying for unknown references
        return new Response(
          JSON.stringify({ received: true, warning: "Payment record not found" }),
          { status: 200, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
        );
      }

      // Use the fallback payment record
      if (status === "success" && paymentByRef.ride_id) {
        await handleSuccessfulPayment(supabase, paymentByRef.ride_id, paymentByRef.id);
      }
    } else if (status === "success" && payment.ride_id) {
      await handleSuccessfulPayment(supabase, payment.ride_id, payment.id);
    }

    console.log(`Chapa webhook processed: tx_ref=${tx_ref}, status=${status}`);

    return new Response(
      JSON.stringify({ received: true, status: internalStatus }),
      { status: 200, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
    );
  } catch (err) {
    console.error("Chapa webhook processing error:", err);
    return new Response(
      JSON.stringify({ error: "Internal server error", details: String(err) }),
      { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
    );
  }
});

/**
 * Handle a successful Chapa payment:
 * - Mark ride as completed (if it's in started state)
 * - Send completion notification to passenger and driver
 */
async function handleSuccessfulPayment(
  supabase:   ReturnType<typeof createClient>,
  rideId:     string,
  paymentId:  string
): Promise<void> {
  // Fetch ride details
  const { data: ride, error: rideError } = await supabase
    .from("rides")
    .select("id, passenger_id, driver_id, status, final_price")
    .eq("id", rideId)
    .single();

  if (rideError || !ride) {
    console.error("Failed to fetch ride for payment:", rideError);
    return;
  }

  // Update ride status to completed if it was started
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

  // Send notifications via the send-notification Edge Function
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
        body:    `Your ride has been completed. Payment of ${ride.final_price ?? ""} ETB confirmed via Chapa.`,
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
        body:    `Payment confirmed for your ride. Amount: ${ride.final_price ?? ""} ETB.`,
        type:    "payment",
        data:    { ride_id: rideId, payment_id: paymentId },
      }),
    });
  }
}
