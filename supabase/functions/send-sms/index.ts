// =============================================================
// Edge Function: send-sms
// Sends Amharic/Arabic SMS notifications for Wedit ride-hailing
// (Addis Ababa, Ethiopia) via a configurable SMS gateway.
//
// Required environment variables (set in Supabase Dashboard):
//   SUPABASE_URL              - Your Supabase project URL
//   SUPABASE_SERVICE_ROLE_KEY - Service role key (bypasses RLS)
//   SMS_PROVIDER              - "africastalking" | "generic" (default: "generic")
//   SMS_API_KEY               - API key / Bearer token for the SMS provider
//   SMS_SENDER_ID             - Sender name shown to recipient (e.g. "Wedit")
//
//   For SMS_PROVIDER=generic (default):
//     SMS_GATEWAY_URL         - Full URL of the generic JSON SMS API endpoint
//
//   For SMS_PROVIDER=africastalking:
//     SMS_AT_USERNAME         - Africa's Talking username (default: "sandbox")
//     (SMS_GATEWAY_URL is ignored; the AT endpoint is hardcoded)
//
// Request body (JSON):
//   {
//     "ride_id":      "uuid",                              // optional
//     "message_type": "ride_start" | "ride_end" | "fleet_driver_invite" | "call_center_dispatch",
//     "phone_number": "+251912345678",
//
//     // ride_start / ride_end fields:
//     "driver_name":  "Ahmed Mohammed",
//     "plate_number": "AA-12345",
//     "total_fare":   95.50,                               // ride_end only
//
//     // fleet_driver_invite fields:
//     "is_new_user":    true | false,
//     "temp_password":  "WD483920"                         // required if is_new_user=true
//
//     // call_center_dispatch fields:
//     "custom_body":    "Wedit: طلب رحلة..."              // full SMS text
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

// ── Amharic / Arabic SMS Templates ────────────────────────────────────────────

function buildRideStartMessage(driverName: string, plateNumber: string): string {
  return `Wedit: ጉዞዎ ተጀምሯል። ሹፌር: ${driverName}፣ መኪና: ${plateNumber}። ስላመለከቱ እናመሰግናለን!`;
}

function buildRideEndMessage(totalFare: number): string {
  return `Wedit: ጉዞዎ ተጠናቋል። የተጓዙበት ሂሳብ: ${totalFare.toFixed(2)} ብር ነው። Weditን ስለተጠቀሙ እናመሰግናለን!`;
}

/**
 * Fleet driver invite templates.
 *
 * New user  → Amharic primary + Arabic secondary (both sent as one combined message).
 * Returning user → Arabic only (they already have the app).
 */
function buildFleetDriverInviteMessage(
  isNewUser: boolean,
  tempPassword?: string
): string {
  if (isNewUser) {
    // Amharic line (primary) + Arabic line (secondary) in a single SMS
    const amharic =
      `Wedit: ተቀጠርህ/ሽ ሹፌር! ቁጥርህ/ሽ: ${tempPassword ?? ""}. ` +
      `ለመጀመር መተግበሪያው ሙሉ ቁጥርህ/ሽ ጻፍ።`;
    const arabic =
      `Wedit: تم تعيينك سائقاً. كلمة المرور المؤقتة: ${tempPassword ?? ""}. ` +
      `حمّل التطبيق وسجّل برقمك.`;
    return `${amharic}\n${arabic}`;
  }

  // Returning driver: Arabic only (they already use the app)
  return "Wedit: تم إضافتك لأسطول. سجّل الدخول للتطبيق لمزيد من التفاصيل.";
}

// ── Normalise phone to E.164 (Ethiopia +251) ──────────────────────────────────

function normalisePhone(phone: string): string {
  const digits = phone.replace(/\D/g, "");
  if (digits.startsWith("251")) return `+${digits}`;
  if (digits.startsWith("0"))   return `+251${digits.slice(1)}`;
  if (digits.length === 9)      return `+251${digits}`;
  return `+${digits}`;
}

// ── Retry helper ──────────────────────────────────────────────────────────────

async function withRetry<T>(
  fn: () => Promise<T>,
  maxAttempts = 3,
  baseDelayMs = 1000
): Promise<T> {
  let lastError: unknown;
  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await fn();
    } catch (err) {
      lastError = err;
      if (attempt < maxAttempts) {
        await new Promise((r) => setTimeout(r, baseDelayMs * 2 ** (attempt - 1)));
      }
    }
  }
  throw lastError;
}

// ── Gateway dispatch ──────────────────────────────────────────────────────────

const AT_ENDPOINT = "https://api.africastalking.com/version1/messaging";

/**
 * Send via Africa's Talking API.
 * Docs: https://developers.africastalking.com/docs/sms/sending
 */
async function sendViaAfricasTalking(
  phone: string,
  message: string,
  apiKey: string,
  senderId: string,
  atUsername: string
): Promise<{ ok: boolean; providerResponse: Record<string, unknown> }> {
  const params = new URLSearchParams({
    username: atUsername,
    to:       phone,
    message,
    from:     senderId,
  });

  const res = await fetch(AT_ENDPOINT, {
    method:  "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
      "Accept":       "application/json",
      "apiKey":       apiKey,
    },
    body: params.toString(),
  });

  let providerResponse: Record<string, unknown>;
  try {
    providerResponse = await res.json();
  } catch {
    providerResponse = { status_code: res.status, raw: await res.text().catch(() => "") };
  }

  // Africa's Talking considers a send successful when the first recipient
  // has status "Success".
  const recipient = (
    (providerResponse?.SMSMessageData as Record<string, unknown>)
      ?.Recipients as Array<Record<string, unknown>>
  )?.[0];

  const ok = recipient?.status === "Success";

  if (!ok) {
    console.error(
      "Africa's Talking send failed:",
      res.status,
      JSON.stringify(providerResponse)
    );
  }

  return { ok, providerResponse };
}

/**
 * Send via a generic JSON POST gateway (original behaviour).
 * Expects the gateway to accept:
 *   { to, from, message }
 * with a Bearer token in the Authorization header.
 */
async function sendViaGenericGateway(
  phone: string,
  message: string,
  gatewayUrl: string,
  apiKey: string,
  senderId: string
): Promise<{ ok: boolean; providerResponse: Record<string, unknown> }> {
  const res = await fetch(gatewayUrl, {
    method: "POST",
    headers: {
      "Content-Type":  "application/json",
      "Authorization": `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      to:      phone,
      from:    senderId,
      message,
    }),
  });

  let providerResponse: Record<string, unknown>;
  try {
    providerResponse = await res.json();
  } catch {
    providerResponse = { status_code: res.status };
  }

  if (!res.ok) {
    console.error("SMS gateway error:", res.status, providerResponse);
  }

  return { ok: res.ok, providerResponse };
}

// ── Main handler ──────────────────────────────────────────────────────────────

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: CORS_HEADERS });
  }

  const supabaseUrl  = Deno.env.get("SUPABASE_URL")!;
  const serviceKey   = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const smsProvider  = (Deno.env.get("SMS_PROVIDER") ?? "generic").toLowerCase();
  const gatewayUrl   = Deno.env.get("SMS_GATEWAY_URL");
  const apiKey       = Deno.env.get("SMS_API_KEY");
  const senderId     = Deno.env.get("SMS_SENDER_ID") ?? "Wedit";
  const atUsername   = Deno.env.get("SMS_AT_USERNAME") ?? "sandbox";

  const supabase = createClient(supabaseUrl, serviceKey);

  // ── Parse body ─────────────────────────────────────────────────────────────

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
    is_new_user,
    temp_password,
    custom_body,
  } = body as {
    ride_id?:       string;
    message_type:   "ride_start" | "ride_end" | "fleet_driver_invite" | "call_center_dispatch";
    phone_number:   string;
    driver_name?:   string;
    plate_number?:  string;
    total_fare?:    number;
    is_new_user?:   boolean;
    temp_password?: string;
    custom_body?:   string;
  };

  // ── Validate required fields ───────────────────────────────────────────────

  if (!message_type || !phone_number) {
    return new Response(
      JSON.stringify({ error: "message_type and phone_number are required" }),
      {
        status: 422,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      }
    );
  }

  if (
    (message_type === "ride_start" || message_type === "ride_end") &&
    (!driver_name || !plate_number)
  ) {
    return new Response(
      JSON.stringify({ error: "driver_name and plate_number required for ride messages" }),
      {
        status: 422,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      }
    );
  }

  if (message_type === "fleet_driver_invite" && is_new_user && !temp_password) {
    return new Response(
      JSON.stringify({ error: "temp_password required when is_new_user=true" }),
      {
        status: 422,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      }
    );
  }

  if (message_type === "call_center_dispatch" && !custom_body) {
    return new Response(
      JSON.stringify({ error: "custom_body required for call_center_dispatch" }),
      {
        status: 422,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      }
    );
  }

  // ── Build message text ─────────────────────────────────────────────────────

  let messageBody: string;

  if (message_type === "ride_start") {
    messageBody = buildRideStartMessage(driver_name!, plate_number!);
  } else if (message_type === "ride_end") {
    if (total_fare === undefined || total_fare === null) {
      return new Response(
        JSON.stringify({ error: "total_fare required for ride_end" }),
        {
          status: 422,
          headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
        }
      );
    }
    messageBody = buildRideEndMessage(total_fare);
  } else if (message_type === "call_center_dispatch") {
    messageBody = custom_body!;
  } else {
    // fleet_driver_invite
    messageBody = buildFleetDriverInviteMessage(
      is_new_user ?? false,
      temp_password
    );
  }

  const recipientPhone = normalisePhone(phone_number);

  // ── Persist log record (pending) ───────────────────────────────────────────

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

  // ── Dev/test mode: no gateway configured ──────────────────────────────────

  const hasCredentials =
    apiKey &&
    (smsProvider === "africastalking" || gatewayUrl);

  if (!hasCredentials) {
    console.warn(
      "SMS credentials not fully configured — message logged only:",
      messageBody
    );
    return new Response(
      JSON.stringify({
        success:  true,
        mode:     "logged_only",
        log_id:   logId,
        message:  messageBody,
        provider: smsProvider,
      }),
      {
        status: 200,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      }
    );
  }

  // ── Send via configured provider ──────────────────────────────────────────

  let ok = false;
  let providerResponse: Record<string, unknown> | null = null;
  let sendStatus: "sent" | "failed" = "failed";
  let sentAt: string | null = null;

  try {
    if (smsProvider === "africastalking") {
      ({ ok, providerResponse } = await withRetry(() =>
        sendViaAfricasTalking(recipientPhone, messageBody, apiKey!, senderId, atUsername)
      ));
    } else {
      // generic (default)
      ({ ok, providerResponse } = await withRetry(() =>
        sendViaGenericGateway(recipientPhone, messageBody, gatewayUrl!, apiKey!, senderId)
      ));
    }

    if (ok) {
      sendStatus = "sent";
      sentAt = new Date().toISOString();
    }
  } catch (fetchErr) {
    console.error("SMS send failed:", fetchErr);
    providerResponse = { error: String(fetchErr) };
  }

  // ── Update log record ──────────────────────────────────────────────────────

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
      success:   sendStatus === "sent",
      status:    sendStatus,
      log_id:    logId,
      message:   messageBody,
      provider:  smsProvider,
      response:  providerResponse,
    }),
    {
      status: sendStatus === "sent" ? 200 : 502,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    }
  );
});
