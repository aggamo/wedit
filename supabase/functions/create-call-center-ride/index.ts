// =============================================================
// Edge Function: create-call-center-ride
// Creates a ride from the call center operator panel.
//
// Required env vars:
//   SUPABASE_URL              — project URL
//   SUPABASE_SERVICE_ROLE_KEY — bypasses RLS for internal ops
//
// POST body:
//   {
//     "passenger_phone":  "+251912345678",
//     "pickup_lat":       9.0246,
//     "pickup_lng":       38.7468,
//     "pickup_address":   "أمام محطة أبا نفسو",
//     "vehicle_type":     "sedan",          // sedan | suv | vip | minibus
//     "notes":            "ينتظر عند الباب الأخضر",  // optional
//     "dropoff_lat":      9.0100,           // optional — enables fare calculation
//     "dropoff_lng":      38.7600,          // optional
//     "dropoff_address":  "ميسكل سكوير"    // optional
//   }
//
// Response (success):
//   { success: true, ride_id, driver_id, driver_name, driver_phone, eta_minutes, estimated_price }
//
// Response (error):
//   { success: false, error: "<message>" }
// =============================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin":  "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const JSON_HEADERS = { ...CORS, "Content-Type": "application/json" };

function normalisePhone(phone: string): string {
  const digits = phone.replace(/\D/g, "");
  if (digits.startsWith("251")) return `+${digits}`;
  if (digits.startsWith("0"))   return `+251${digits.slice(1)}`;
  if (digits.length === 9)      return `+251${digits}`;
  return `+${digits}`;
}

function ok(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: JSON_HEADERS });
}
function err(message: string, status = 400): Response {
  return new Response(JSON.stringify({ success: false, error: message }), {
    status,
    headers: JSON_HEADERS,
  });
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS });

  const supabaseUrl    = Deno.env.get("SUPABASE_URL")!;
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  // ── Auth: verify caller is admin or active call_center_agent ────────────────
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return err("Missing Authorization header", 401);

  // User-scoped client to get caller identity
  const userClient = createClient(supabaseUrl, Deno.env.get("SUPABASE_ANON_KEY") ?? serviceRoleKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: { user }, error: authErr } = await userClient.auth.getUser();
  if (authErr || !user) return err("Unauthorized", 401);

  // Service-role client for all DB writes
  const svc = createClient(supabaseUrl, serviceRoleKey);

  // Check role
  const { data: profile } = await svc
    .from("profiles")
    .select("role")
    .eq("id", user.id)
    .maybeSingle();

  const isAdmin = profile?.role === "admin";
  let isAgent  = false;
  if (!isAdmin) {
    const { data: agent } = await svc
      .from("call_center_agents")
      .select("id")
      .eq("profile_id", user.id)
      .eq("is_active", true)
      .maybeSingle();
    isAgent = agent != null;
  }

  if (!isAdmin && !isAgent) return err("Forbidden — admin or call center agent required", 403);

  // ── Parse body ───────────────────────────────────────────────────────────────
  let body: Record<string, unknown>;
  try { body = await req.json(); }
  catch { return err("Invalid JSON body"); }

  const {
    passenger_phone,
    pickup_lat,
    pickup_lng,
    pickup_address,
    vehicle_type    = "sedan",
    notes           = "",
    dropoff_lat,
    dropoff_lng,
    dropoff_address = "",
  } = body as {
    passenger_phone:  string;
    pickup_lat:       number;
    pickup_lng:       number;
    pickup_address:   string;
    vehicle_type?:    string;
    notes?:           string;
    dropoff_lat?:     number;
    dropoff_lng?:     number;
    dropoff_address?: string;
  };

  if (!passenger_phone || pickup_lat == null || pickup_lng == null || !pickup_address) {
    return err("Missing required fields: passenger_phone, pickup_lat, pickup_lng, pickup_address");
  }

  // ── Calculate estimated fare if destination is known ─────────────────────
  let estimatedPrice: number | null = null;
  if (dropoff_lat != null && dropoff_lng != null) {
    const { data: fareData } = await svc.rpc("calculate_estimated_price", {
      p_pickup_lat:       pickup_lat,
      p_pickup_lng:       pickup_lng,
      p_dropoff_lat:      dropoff_lat,
      p_dropoff_lng:      dropoff_lng,
      p_vehicle_type:     vehicle_type,
      p_surge_multiplier: 1.0,
    });
    if (fareData && typeof fareData === "object") {
      estimatedPrice = (fareData as Record<string, unknown>).total as number ?? null;
    }
  }

  const normalPhone = normalisePhone(passenger_phone);

  // ── Find nearest available driver ────────────────────────────────────────────
  // Query driver_locations joined with drivers for online + active + matching vehicle type
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

  if (driversErr) {
    console.error("find_nearby_drivers error:", driversErr.message);
    // Fallback: manual geo query
    const { data: fallbackDrivers } = await svc
      .from("driver_locations")
      .select("driver_id, lat, lng")
      .eq("is_online", true);

    if (!fallbackDrivers || fallbackDrivers.length === 0) {
      return ok({ success: false, error: "لا يوجد سائق متاح في المنطقة حالياً" });
    }

    // Pick nearest by Euclidean distance
    const nearest = fallbackDrivers.reduce((best: typeof fallbackDrivers[0], d: typeof fallbackDrivers[0]) => {
      const distD = Math.pow(d.lat - pickup_lat, 2) + Math.pow(d.lng - pickup_lng, 2);
      const distB = Math.pow(best.lat - pickup_lat, 2) + Math.pow(best.lng - pickup_lng, 2);
      return distD < distB ? d : best;
    });

    return createRide(
    svc, nearest.driver_id, normalPhone,
    pickup_lat, pickup_lng, pickup_address,
    vehicle_type, notes,
    dropoff_lat ?? null, dropoff_lng ?? null, dropoff_address,
    estimatedPrice,
  );
  }

  if (!nearbyDrivers || nearbyDrivers.length === 0) {
    return ok({ success: false, error: "لا يوجد سائق متاح في المنطقة حالياً" });
  }

  const closestDriverId = (nearbyDrivers[0] as Record<string, unknown>).driver_id as string;
  return createRide(
    svc, closestDriverId, normalPhone,
    pickup_lat, pickup_lng, pickup_address,
    vehicle_type, notes,
    dropoff_lat ?? null, dropoff_lng ?? null, dropoff_address,
    estimatedPrice,
  );
});

// ── Helper: create the ride, notify driver ──────────────────────────────────────

async function createRide(
  svc: ReturnType<typeof createClient>,
  driverId: string,
  passengerPhone: string,
  pickupLat: number,
  pickupLng: number,
  pickupAddress: string,
  vehicleType: string,
  notes: string,
  dropoffLat: number | null,
  dropoffLng: number | null,
  dropoffAddress: string,
  estimatedPrice: number | null,
): Promise<Response> {
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const JSON_HEADERS = {
    "Access-Control-Allow-Origin": "*",
    "Content-Type": "application/json",
  };

  // Get driver info for notification
  const { data: driverRow } = await svc
    .from("drivers")
    .select("id, profiles(full_name, phone, fcm_token)")
    .eq("id", driverId)
    .maybeSingle();

  const driverProfile = driverRow?.profiles as Record<string, unknown> | undefined;
  const driverName  = (driverProfile?.full_name as string) ?? "سائق";
  const driverPhone = (driverProfile?.phone     as string) ?? "";
  const fcmToken    = (driverProfile?.fcm_token  as string) ?? null;

  // Create ride record
  const { data: ride, error: rideErr } = await svc
    .from("rides")
    .insert({
      driver_id:       driverId,
      passenger_phone: passengerPhone,
      pickup_lat:      pickupLat,
      pickup_lng:      pickupLng,
      pickup_address:  pickupAddress,
      dropoff_lat:     dropoffLat,
      dropoff_lng:     dropoffLng,
      dropoff_address: dropoffAddress || null,
      ride_type:       "call_center",
      status:          "accepted",
      vehicle_type:    vehicleType,
      notes:           notes || null,
      estimated_price: estimatedPrice,
    })
    .select("id")
    .single();

  if (rideErr || !ride) {
    console.error("Ride insert error:", rideErr?.message);
    return new Response(
      JSON.stringify({ success: false, error: "فشل إنشاء الرحلة: " + (rideErr?.message ?? "unknown") }),
      { status: 500, headers: JSON_HEADERS },
    );
  }

  const rideId = ride.id as string;

  // Estimate ETA (rough: 2 min + 1 min per km within 5 km)
  const etaMinutes = 5;

  // ── Send push notification (fire & forget) ──────────────────────────────────
  if (fcmToken) {
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    fetch(`${supabaseUrl}/functions/v1/send-notification`, {
      method:  "POST",
      headers: {
        "Content-Type":  "application/json",
        "Authorization": `Bearer ${serviceRoleKey}`,
      },
      body: JSON.stringify({
        user_id: driverId,
        title:   "📞 طلب رحلة — كول سنتر",
        body:    `راكب ينتظرك في: ${pickupAddress}`,
        type:    "call_center_ride",
        data: {
          ride_id:        rideId,
          passenger_phone: passengerPhone,
          pickup_lat:     String(pickupLat),
          pickup_lng:     String(pickupLng),
          pickup_address:  pickupAddress,
          vehicle_type:    vehicleType,
          ride_type:       "call_center",
        },
      }),
    }).catch((e) => console.warn("FCM send failed:", e));
  }

  // ── SMS fallback after 30 s if driver didn't respond ────────────────────────
  // We schedule an SMS now; ideally a cron/function would check acceptance status.
  // For simplicity, always send SMS as backup (Africa's Talking is cheap).
  if (driverPhone) {
    const smsBody = `Wedit: طلب رحلة من الكول سنتر. موقع الراكب: ${pickupAddress}. هاتف الراكب: ${passengerPhone}. رقم الرحلة: ${rideId.slice(0, 8)}`;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
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

  return new Response(
    JSON.stringify({
      success:         true,
      ride_id:         rideId,
      driver_id:       driverId,
      driver_name:     driverName,
      driver_phone:    driverPhone,
      eta_minutes:     etaMinutes,
      estimated_price: estimatedPrice,
    }),
    { status: 200, headers: JSON_HEADERS },
  );
}
