// =============================================================
// Edge Function: decline-call-center-ride
// Called by the driver app when a driver declines a call_center
// or ai_call ride. Logs the decline and reassigns to the next
// nearest available driver. After 5 declines, sets ride to
// 'seeking' status for automatic retry after 2 minutes.
//
// Auth: Bearer JWT (driver must be the currently assigned driver)
//
// POST body:
//   { "ride_id": "<uuid>" }
//
// Response:
//   { success: true, reassigned: true, new_driver_id: "..." }
//   { success: true, seeking: true }
//   { success: false, error: "..." }
// =============================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin":  "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const JSON_HEADERS = { ...CORS, "Content-Type": "application/json" };

const MAX_DECLINES = 5;

function ok(body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), { status: 200, headers: JSON_HEADERS });
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

  // ── Auth: get caller identity ─────────────────────────────────────────────
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return err("Missing Authorization header", 401);

  const userClient = createClient(
    supabaseUrl,
    Deno.env.get("SUPABASE_ANON_KEY") ?? serviceRoleKey,
    { global: { headers: { Authorization: authHeader } } },
  );
  const { data: { user }, error: authErr } = await userClient.auth.getUser();
  if (authErr || !user) return err("Unauthorized", 401);

  const svc = createClient(supabaseUrl, serviceRoleKey);

  // ── Parse body ────────────────────────────────────────────────────────────
  let body: Record<string, unknown>;
  try { body = await req.json(); }
  catch { return err("Invalid JSON body"); }

  const { ride_id } = body as { ride_id?: string };
  if (!ride_id) return err("Missing ride_id");

  // ── Verify this driver is currently assigned to the ride ──────────────────
  const { data: ride, error: rideErr } = await svc
    .from("rides")
    .select("id, driver_id, status, ride_type, pickup_lat, pickup_lng, vehicle_type")
    .eq("id", ride_id)
    .maybeSingle();

  if (rideErr || !ride) return err("Ride not found", 404);
  if (ride.driver_id !== user.id) return err("Not your ride", 403);
  if (!["accepted", "seeking"].includes(ride.status as string)) {
    return err("Ride is not in a declinable state");
  }

  // ── Log the decline ───────────────────────────────────────────────────────
  await svc.from("ride_declines").insert({
    ride_id:   ride_id,
    driver_id: user.id,
  });

  // ── Count total declines for this ride ────────────────────────────────────
  const { count: declineCount } = await svc
    .from("ride_declines")
    .select("id", { count: "exact", head: true })
    .eq("ride_id", ride_id);

  const totalDeclines = declineCount ?? 0;

  // ── Get IDs of all drivers who already declined ───────────────────────────
  const { data: declineRows } = await svc
    .from("ride_declines")
    .select("driver_id")
    .eq("ride_id", ride_id);

  const declinedDriverIds = (declineRows ?? []).map(
    (r: Record<string, unknown>) => r.driver_id as string,
  );

  // ── Try to find next nearest driver (excluding declined) ──────────────────
  let nextDriverId: string | null = null;

  if (totalDeclines < MAX_DECLINES) {
    const { data: nearbyDrivers } = await svc.rpc("find_nearby_drivers", {
      lat:          ride.pickup_lat,
      lng:          ride.pickup_lng,
      radius_km:    5,
      vehicle_type: ride.vehicle_type,
      dest_lat:     ride.pickup_lat,
      dest_lng:     ride.pickup_lng,
    });

    const candidates = ((nearbyDrivers ?? []) as Array<Record<string, unknown>>)
      .filter((d) => !declinedDriverIds.includes(d.driver_id as string));

    if (candidates.length > 0) {
      nextDriverId = candidates[0].driver_id as string;
    } else {
      // RPC returned nothing — fallback Euclidean
      const { data: allOnline } = await svc
        .from("driver_locations")
        .select("driver_id, lat, lng")
        .eq("is_online", true)
        .not("driver_id", "in", `(${declinedDriverIds.join(",")})`);

      if (allOnline && allOnline.length > 0) {
        const nearest = (allOnline as Array<{ driver_id: string; lat: number; lng: number }>)
          .reduce((best, d) => {
            const dd = Math.pow(d.lat - ride.pickup_lat, 2) + Math.pow(d.lng - ride.pickup_lng, 2);
            const db = Math.pow(best.lat - ride.pickup_lat, 2) + Math.pow(best.lng - ride.pickup_lng, 2);
            return dd < db ? d : best;
          });
        nextDriverId = nearest.driver_id;
      }
    }
  }

  // ── Reassign or go to seeking ─────────────────────────────────────────────
  if (nextDriverId) {
    // Reassign to next driver
    await svc
      .from("rides")
      .update({ driver_id: nextDriverId, status: "accepted" })
      .eq("id", ride_id);

    // Get next driver info for FCM
    const { data: driverRow } = await svc
      .from("drivers")
      .select("id, profiles(full_name, phone, fcm_token)")
      .eq("id", nextDriverId)
      .maybeSingle();

    const profile = driverRow?.profiles as Record<string, unknown> | undefined;
    const fcmToken = profile?.fcm_token as string | null;
    const pickupAddress = (ride as Record<string, unknown>).pickup_address as string ?? "";

    if (fcmToken) {
      fetch(`${supabaseUrl}/functions/v1/send-notification`, {
        method:  "POST",
        headers: {
          "Content-Type":  "application/json",
          "Authorization": `Bearer ${serviceRoleKey}`,
        },
        body: JSON.stringify({
          user_id: nextDriverId,
          title:   "📞 طلب رحلة — كول سنتر",
          body:    `راكب ينتظرك في: ${pickupAddress}`,
          type:    "call_center_ride",
          data: {
            ride_id:        ride_id,
            pickup_lat:     String(ride.pickup_lat),
            pickup_lng:     String(ride.pickup_lng),
            pickup_address: pickupAddress,
            vehicle_type:   ride.vehicle_type,
            ride_type:      ride.ride_type,
          },
        }),
      }).catch((e) => console.warn("FCM send failed:", e));
    }

    return ok({ success: true, reassigned: true, new_driver_id: nextDriverId });
  }

  // No driver found — set to seeking, retry after 2 minutes
  await svc
    .from("rides")
    .update({
      driver_id:     null,
      status:        "seeking",
      seek_retry_at: new Date(Date.now() + 2 * 60 * 1000).toISOString(),
    })
    .eq("id", ride_id);

  return ok({ success: true, seeking: true });
});
