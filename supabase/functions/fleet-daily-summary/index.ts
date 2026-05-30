// =============================================================
// Edge Function: fleet-daily-summary
// Sends daily earnings summary to fleet owners with the feature enabled
// Scheduled daily at 8am via cron
// =============================================================
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: CORS_HEADERS });
  }

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // Yesterday's date range
    const now = new Date();
    const yesterday = new Date(now);
    yesterday.setDate(yesterday.getDate() - 1);
    yesterday.setHours(0, 0, 0, 0);
    const yesterdayEnd = new Date(yesterday);
    yesterdayEnd.setHours(23, 59, 59, 999);

    // Get all active fleet owners with daily_summary_notification enabled
    const { data: owners, error } = await supabase
      .from("fleet_owners")
      .select(`
        id,
        subscription_plan_id,
        fleet_owner_subscription_plans!inner(features),
        profiles!inner(fcm_token)
      `)
      .eq("is_active", true);

    if (error || !owners) return new Response("OK", { status: 200 });

    for (const owner of owners) {
      const plan = owner.fleet_owner_subscription_plans as { features: Record<string, boolean> };
      if (!plan?.features?.daily_summary_notification) continue;

      const fcmToken = (owner.profiles as { fcm_token: string })?.fcm_token;
      if (!fcmToken) continue;

      // Get yesterday's rides for this owner's fleet
      const { data: assignments } = await supabase
        .from("fleet_driver_assignments")
        .select("driver_id, revenue_share_type, revenue_share_value")
        .eq("fleet_owner_id", owner.id)
        .eq("is_active", true);

      if (!assignments || assignments.length === 0) continue;

      const driverIds = assignments.map((a) => a.driver_id);

      const { data: rides } = await supabase
        .from("rides")
        .select("driver_id, final_price")
        .in("driver_id", driverIds)
        .eq("status", "completed")
        .gte("completed_at", yesterday.toISOString())
        .lte("completed_at", yesterdayEnd.toISOString());

      const totalRides = rides?.length ?? 0;
      const totalFare = rides?.reduce((sum, r) => sum + (r.final_price ?? 0), 0) ?? 0;

      // Calculate owner's share across all drivers
      let ownerTotal = 0;
      for (const assignment of assignments) {
        const driverRides = rides?.filter((r) => r.driver_id === assignment.driver_id) ?? [];
        const driverFare = driverRides.reduce((sum, r) => sum + (r.final_price ?? 0), 0);
        if (assignment.revenue_share_type === "percentage") {
          ownerTotal += driverFare * (1 - assignment.revenue_share_value / 100);
        } else {
          ownerTotal += Math.min(driverFare, assignment.revenue_share_value);
        }
      }

      await supabase.functions.invoke("send-notification", {
        body: {
          user_id: owner.id,
          title: "ملخص أرباح أمس",
          body: `${totalRides} رحلة — إجمالي ${totalFare.toFixed(0)} بر — حصتك ${ownerTotal.toFixed(0)} بر`,
          type: "general",
          data: { type: "fleet_daily_summary", total_rides: totalRides, owner_share: ownerTotal },
        },
      });
    }

    return new Response(JSON.stringify({ success: true }), {
      status: 200,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  }
});
