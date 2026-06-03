// =============================================================
// Edge Function: check-retry-rides
// Picks up rides stuck in 'seeking' status whose retry window
// has elapsed, clears old declines, and re-dispatches them.
//
// Trigger: Supabase pg_cron every minute —
//   SELECT cron.schedule(
//     'retry-seeking-rides', '* * * * *',
//     $$SELECT net.http_post(
//       '<SUPABASE_URL>/functions/v1/check-retry-rides',
//       headers => '{"Authorization":"Bearer <SERVICE_KEY>"}'::jsonb
//     )$$
//   );
//
// No request body needed — uses service role for all ops.
// =============================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const HEADERS = { "Content-Type": "application/json" };

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204 });

  const supabaseUrl    = Deno.env.get("SUPABASE_URL")!;
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  // Require service-role or internal call
  const auth = req.headers.get("Authorization") ?? "";
  if (!auth.includes(serviceRoleKey)) {
    return new Response(JSON.stringify({ error: "Forbidden" }), {
      status: 403,
      headers: HEADERS,
    });
  }

  const svc = createClient(supabaseUrl, serviceRoleKey);

  // ── Find rides due for retry ──────────────────────────────────────────────
  const { data: seekingRides, error } = await svc
    .from("rides")
    .select("id, pickup_lat, pickup_lng, vehicle_type, ride_type, pickup_address, passenger_phone")
    .eq("status", "seeking")
    .lte("seek_retry_at", new Date().toISOString());

  if (error || !seekingRides || seekingRides.length === 0) {
    return new Response(
      JSON.stringify({ processed: 0 }),
      { status: 200, headers: HEADERS },
    );
  }

  let dispatched = 0;
  let retried    = 0;

  for (const ride of seekingRides as Array<Record<string, unknown>>) {
    const rideId = ride.id as string;

    // Clear old declines so we try fresh set of drivers
    await svc.from("ride_declines").delete().eq("ride_id", rideId);

    // Find nearest driver
    const { data: nearbyDrivers } = await svc.rpc("find_nearby_drivers", {
      lat:          ride.pickup_lat,
      lng:          ride.pickup_lng,
      radius_km:    5,
      vehicle_type: ride.vehicle_type,
      dest_lat:     ride.pickup_lat,
      dest_lng:     ride.pickup_lng,
    });

    let nextDriverId: string | null = null;

    if (nearbyDrivers && nearbyDrivers.length > 0) {
      nextDriverId = (nearbyDrivers[0] as Record<string, unknown>).driver_id as string;
    } else {
      // Euclidean fallback
      const { data: allOnline } = await svc
        .from("driver_locations")
        .select("driver_id, lat, lng")
        .eq("is_online", true);

      if (allOnline && allOnline.length > 0) {
        const nearest = (allOnline as Array<{ driver_id: string; lat: number; lng: number }>)
          .reduce((best, d) => {
            const dd = Math.pow(d.lat - (ride.pickup_lat as number), 2) +
                       Math.pow(d.lng - (ride.pickup_lng as number), 2);
            const db = Math.pow(best.lat - (ride.pickup_lat as number), 2) +
                       Math.pow(best.lng - (ride.pickup_lng as number), 2);
            return dd < db ? d : best;
          });
        nextDriverId = nearest.driver_id;
      }
    }

    if (nextDriverId) {
      // Reassign
      await svc
        .from("rides")
        .update({ driver_id: nextDriverId, status: "accepted", seek_retry_at: null })
        .eq("id", rideId);

      // Notify driver
      const { data: driverRow } = await svc
        .from("drivers")
        .select("id, profiles(full_name, fcm_token)")
        .eq("id", nextDriverId)
        .maybeSingle();

      const profile  = driverRow?.profiles as Record<string, unknown> | undefined;
      const fcmToken = profile?.fcm_token as string | null;

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
            body:    `راكب ينتظرك في: ${ride.pickup_address ?? "الموقع المحدد"}`,
            type:    "call_center_ride",
            data: {
              ride_id:        rideId,
              pickup_lat:     String(ride.pickup_lat),
              pickup_lng:     String(ride.pickup_lng),
              pickup_address: ride.pickup_address ?? "",
              vehicle_type:   ride.vehicle_type,
              ride_type:      ride.ride_type,
            },
          }),
        }).catch((e) => console.warn("FCM send failed:", e));
      }

      dispatched++;
    } else {
      // Still no driver — push retry window forward
      await svc
        .from("rides")
        .update({ seek_retry_at: new Date(Date.now() + 2 * 60 * 1000).toISOString() })
        .eq("id", rideId);

      retried++;
    }
  }

  return new Response(
    JSON.stringify({ processed: seekingRides.length, dispatched, retried }),
    { status: 200, headers: HEADERS },
  );
});
