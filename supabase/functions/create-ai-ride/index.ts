// =============================================================
// Edge Function: create-ai-ride
// Called by handle-voice-session after speech is understood.
// Finds nearest driver, creates ai_call ride, notifies driver.
//
// Required env vars:
//   SUPABASE_URL              — project URL
//   SUPABASE_SERVICE_ROLE_KEY — bypasses RLS
//   AI_CALL_WEBHOOK_SECRET    — shared secret for auth
//
// POST body:
//   {
//     "log_id":           "uuid",            // ai_call_logs row
//     "passenger_phone":  "+251...",
//     "pickup_lat":       9.0246,
//     "pickup_lng":       38.7468,
//     "pickup_text":      "ቦሌ ሮድ",
//     "destination_text": "ፒያሳ",            // optional
//     "vehicle_type":     "sedan",
//     "transcript":       "...",
//     "confidence_score": 0.87
//   }
//
// Response:
//   { success: true,  driver_name, driver_phone, eta_minutes }
//   { success: false, error: "no_driver" | "<message>" }
// =============================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin":  "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-wedit-secret",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const JSON_HEADERS = { ...CORS, "Content-Type": "application/json" };

function ok(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: JSON_HEADERS });
}
function err(message: string, status = 400): Response {
  return new Response(JSON.stringify({ success: false, error: message }), {
    status,
    headers: JSON_HEADERS,
  });
}

function normalisePhone(phone: string): string {
  const digits = phone.replace(/\D/g, "");
  if (digits.startsWith("251")) return `+${digits}`;
  if (digits.startsWith("0"))   return `+251${digits.slice(1)}`;
  if (digits.length === 9)      return `+251${digits}`;
  return `+${digits}`;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS });

  // ── Auth: shared secret ────────────────────────────────────────────────────
  const webhookSecret = Deno.env.get("AI_CALL_WEBHOOK_SECRET");
  const clientSecret  = req.headers.get("X-Wedit-Secret");
  if (!webhookSecret || clientSecret !== webhookSecret) {
    return err("Forbidden", 403);
  }

  const supabaseUrl    = Deno.env.get("SUPABASE_URL")!;
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const svc            = createClient(supabaseUrl, serviceRoleKey);

  // ── Parse body ─────────────────────────────────────────────────────────────
  let body: Record<string, unknown>;
  try { body = await req.json(); }
  catch { return err("Invalid JSON body"); }

  const {
    log_id,
    passenger_phone,
    pickup_lat,
    pickup_lng,
    pickup_text    = "",
    destination_text = "",
    vehicle_type   = "sedan",
    transcript     = "",
    confidence_score = 0,
  } = body as {
    log_id?:           string;
    passenger_phone:   string;
    pickup_lat:        number;
    pickup_lng:        number;
    pickup_text?:      string;
    destination_text?: string;
    vehicle_type?:     string;
    transcript?:       string;
    confidence_score?: number;
  };

  if (!passenger_phone || pickup_lat == null || pickup_lng == null) {
    return err("Missing required fields: passenger_phone, pickup_lat, pickup_lng");
  }

  const normalPhone = normalisePhone(passenger_phone as string);

  // ── Find nearest available driver ──────────────────────────────────────────
  const { data: nearbyDrivers, error: driversErr } = await svc.rpc(
    "find_nearby_drivers",
    {
      lat:          pickup_lat,
      lng:          pickup_lng,
      radius_km:    5,
      vehicle_type: vehicle_type,
      dest_lat:     pickup_lat,
      dest_lng:     pickup_lng,
    }
  );

  let closestDriverId: string | null = null;

  if (driversErr || !nearbyDrivers || nearbyDrivers.length === 0) {
    // Fallback: simple Euclidean query
    const { data: fallback } = await svc
      .from("driver_locations")
      .select("driver_id, lat, lng")
      .eq("is_online", true);

    if (fallback && fallback.length > 0) {
      const nearest = (fallback as Array<{ driver_id: string; lat: number; lng: number }>)
        .reduce((best, d) => {
          const dDist = Math.pow(d.lat - (pickup_lat as number), 2) + Math.pow(d.lng - (pickup_lng as number), 2);
          const bDist = Math.pow(best.lat - (pickup_lat as number), 2) + Math.pow(best.lng - (pickup_lng as number), 2);
          return dDist < bDist ? d : best;
        });
      closestDriverId = nearest.driver_id;
    }
  } else {
    closestDriverId = (nearbyDrivers[0] as Record<string, unknown>).driver_id as string;
  }

  if (!closestDriverId) {
    // No driver — update log
    if (log_id) {
      await svc.from("ai_call_logs").update({ status: "no_driver" }).eq("id", log_id);
    }
    return ok({ success: false, error: "no_driver" });
  }

  // ── Get driver info ────────────────────────────────────────────────────────
  const { data: driverRow } = await svc
    .from("drivers")
    .select("id, profiles(full_name, phone, fcm_token)")
    .eq("id", closestDriverId)
    .maybeSingle();

  const driverProfile = driverRow?.profiles as Record<string, unknown> | undefined;
  const driverName    = (driverProfile?.full_name as string) ?? "سائق";
  const driverPhone   = (driverProfile?.phone      as string) ?? "";
  const fcmToken      = (driverProfile?.fcm_token   as string) ?? null;

  // ── Create ride ────────────────────────────────────────────────────────────
  const { data: ride, error: rideErr } = await svc
    .from("rides")
    .insert({
      driver_id:       closestDriverId,
      passenger_phone: normalPhone,
      pickup_lat:      pickup_lat,
      pickup_lng:      pickup_lng,
      pickup_address:  pickup_text as string || `${pickup_lat}, ${pickup_lng}`,
      ride_type:       "ai_call",
      status:          "accepted",
      vehicle_type:    vehicle_type,
      notes:           destination_text ? `وجهة: ${destination_text}` : null,
    })
    .select("id")
    .single();

  if (rideErr || !ride) {
    console.error("Ride insert error:", rideErr?.message);
    if (log_id) {
      await svc.from("ai_call_logs").update({ status: "failed" }).eq("id", log_id);
    }
    return err("Failed to create ride: " + (rideErr?.message ?? "unknown"), 500);
  }

  const rideId = ride.id as string;

  // ── Update ai_call_logs ────────────────────────────────────────────────────
  if (log_id) {
    await svc.from("ai_call_logs").update({
      status:  "dispatched",
      ride_id: rideId,
    }).eq("id", log_id);
  }

  const etaMinutes = 5;

  // ── Send push notification (fire & forget) ─────────────────────────────────
  if (fcmToken) {
    fetch(`${supabaseUrl}/functions/v1/send-notification`, {
      method:  "POST",
      headers: {
        "Content-Type":  "application/json",
        "Authorization": `Bearer ${serviceRoleKey}`,
      },
      body: JSON.stringify({
        user_id: closestDriverId,
        title:   "🤖 طلب رحلة — المساعد الصوتي",
        body:    `راكب ينتظرك في: ${pickup_text || "الموقع المحدد"}`,
        type:    "ai_call",
        data: {
          ride_id:         rideId,
          passenger_phone: normalPhone,
          pickup_lat:      String(pickup_lat),
          pickup_lng:      String(pickup_lng),
          pickup_address:  pickup_text as string,
          vehicle_type:    vehicle_type as string,
          ride_type:       "ai_call",
        },
      }),
    }).catch((e) => console.warn("FCM send failed:", e));
  }

  // ── Send SMS backup (fire & forget) ───────────────────────────────────────
  if (driverPhone) {
    const smsBody = `Wedit: طلب رحلة من المساعد الصوتي. موقع الراكب: ${pickup_text || `${pickup_lat}, ${pickup_lng}`}. هاتف الراكب: ${normalPhone}. رقم الرحلة: ${rideId.slice(0, 8)}`;
    fetch(`${supabaseUrl}/functions/v1/send-sms`, {
      method:  "POST",
      headers: {
        "Content-Type":  "application/json",
        "Authorization": `Bearer ${serviceRoleKey}`,
      },
      body: JSON.stringify({
        ride_id:      rideId,
        message_type: "call_center_dispatch",
        phone_number: driverPhone,
        driver_name:  driverName,
        plate_number: "",
        custom_body:  smsBody,
      }),
    }).catch((e) => console.warn("SMS send failed:", e));
  }

  return ok({
    success:      true,
    ride_id:      rideId,
    driver_id:    closestDriverId,
    driver_name:  driverName,
    driver_phone: driverPhone,
    eta_minutes:  etaMinutes,
  });
});
