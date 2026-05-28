// =============================================================
// Edge Function: send-sms
// Sends Amharic SMS notifications for Wedit street-hail rides
// via a configurable HTTP POST SMS gateway.
//
// Required environment variables (set in Supabase Dashboard):
//   SMS_GATEWAY_URL  - Full URL of the SMS API endpoint
//   SMS_API_KEY      - Bearer token / API key for the gateway
//   SMS_SENDER_ID    - Sender name shown to recipient (e.g. "Wedit")
//
// Request body (JSON):
//   {
//     "ride_id":      "uuid",
//     "message_type": "ride_start" | "ride_end",
//     "phone_number": "+251912345678",
//     "driver_name":  "Ahmed Mohammed",
//     "plate_number": "AA-12345",
//     "total_fare":   95.50          // only for ride_end
//   }
// =============================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// ── Amharic SMS Templates ──────────────────────────────────────────────────────

function buildRideStartMessage(driverName: string, plateNumber: string): string {
  return `Wedit: ጉዞዎ ተጀምሯል። ሹፌር: ${driverName}፣ መኪና: ${plateNumber}። ስላመለከቱ እናመሰግናለን!`;
}

function buildRideEndMessage(totalFare: number): string {
  return `Wedit: ጉዞዎ ተጠናቋል። የተጓዙበት ሂሳብ: ${totalFare.toFixed(2)} ብር ነው። Weditን ስለተጠቀሙ እናመሰግናለን!`;
}

// ── Normalise phone to E.164 (Ethiopia +251) ──────────────────────────────────

function normalisePhone(phone: string): string {
  const digits = phone.replace(/\D/g, "");
  if (digits.startsWith("251")) return `+${digits}`;
  if (digits.startsWith("0"))   return `+251${digits.slice(1)}`;
  if (digits.length === 9)      return `+251${digits}`;
  return `+${digits}`;
}

// ── Main handler ──────────────────────────────────────────────────────────────

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: CORS_HEADERS });
  }

  const supabaseUrl  = Deno.env.get("SUPABASE_URL")!;
  const serviceKey   = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const gatewayUrl   = Deno.env.get("SMS_GATEWAY_URL");
  const apiKey       = Deno.env.get("SMS_API_KEY");
  const senderId     = Deno.env.get("SMS_SENDER_ID") ?? "Wedit";

  const supabase = createClient(supabaseUrl, serviceKey);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON body" }), {
      status: 400,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  }

  const {
    ride_id,
    message_type,
    phone_number,
    driver_name,
    plate_number,
    total_fare,
  } = body as {
    ride_id?: string;
    message_type: "ride_start" | "ride_end";
    phone_number: string;
    driver_name: string;
    plate_number: string;
    total_fare?: number;
  };

  if (!message_type || !phone_number || !driver_name || !plate_number) {
    return new Response(
      JSON.stringify({ error: "Missing required fields" }),
      {
        status: 422,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      }
    );
  }

  // Build message
  let messageBody: string;
  if (message_type === "ride_start") {
    messageBody = buildRideStartMessage(driver_name, plate_number);
  } else {
    if (total_fare === undefined || total_fare === null) {
      return new Response(
        JSON.stringify({ error: "total_fare required for ride_end" }),
        {
          status: 422,
          headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
        }
      );
    }
    messageBody = buildRideEndMessage(total_fare as number);
  }

  const recipientPhone = normalisePhone(phone_number);

  // Persist log (pending)
  const { data: logRecord, error: logErr } = await supabase
    .from("sms_logs")
    .insert({
      ride_id:      ride_id ?? null,
      phone_number: recipientPhone,
      message_type,
      message_body: messageBody,
      status:       "pending",
    })
    .select("id")
    .single();

  if (logErr) {
    console.error("sms_logs insert error:", logErr.message);
  }

  const logId: string | undefined = logRecord?.id;

  // If no gateway configured, stay as pending (dev/test mode)
  if (!gatewayUrl || !apiKey) {
    console.warn(
      "SMS_GATEWAY_URL or SMS_API_KEY not set — message logged only:",
      messageBody
    );
    return new Response(
      JSON.stringify({
        success: true,
        mode: "logged_only",
        log_id: logId,
        message: messageBody,
      }),
      {
        status: 200,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      }
    );
  }

  // Send via HTTP POST gateway
  let providerResponse: Record<string, unknown> | null = null;
  let sendStatus: "sent" | "failed" = "failed";
  let sentAt: string | null = null;

  try {
    const gatewayRes = await fetch(gatewayUrl, {
      method: "POST",
      headers: {
        "Content-Type":  "application/json",
        "Authorization": `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        to:      recipientPhone,
        from:    senderId,
        message: messageBody,
      }),
    });

    providerResponse = await gatewayRes.json().catch(() => ({
      status_code: gatewayRes.status,
    }));

    if (gatewayRes.ok) {
      sendStatus = "sent";
      sentAt = new Date().toISOString();
    } else {
      console.error("SMS gateway error:", gatewayRes.status, providerResponse);
    }
  } catch (fetchErr) {
    console.error("SMS gateway fetch failed:", fetchErr);
    providerResponse = { error: String(fetchErr) };
  }

  // Update log record
  if (logId) {
    await supabase
      .from("sms_logs")
      .update({
        status:            sendStatus,
        provider_response: providerResponse,
        sent_at:           sentAt,
      })
      .eq("id", logId);
  }

  return new Response(
    JSON.stringify({
      success:  sendStatus === "sent",
      status:   sendStatus,
      log_id:   logId,
      message:  messageBody,
      response: providerResponse,
    }),
    {
      status: sendStatus === "sent" ? 200 : 502,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    }
  );
});
