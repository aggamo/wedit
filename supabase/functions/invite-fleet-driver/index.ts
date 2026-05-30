// =============================================================
// Edge Function: invite-fleet-driver
// Links an existing driver or creates a new account and sends SMS
// =============================================================
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

interface InvitePayload {
  phone: string;
  fleet_owner_id: string;
  fleet_vehicle_id: string;
  revenue_share_type: "percentage" | "daily_rent" | "weekly_rent" | "monthly_rent";
  revenue_share_value: number;
  settlement_cycle?: "daily" | "weekly" | "monthly";
  max_daily_trips?: number | null;
}

function generateTempPassword(): string {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: CORS_HEADERS });
  }

  try {
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    const payload: InvitePayload = await req.json();
    const {
      phone,
      fleet_owner_id,
      fleet_vehicle_id,
      revenue_share_type,
      revenue_share_value,
      settlement_cycle = "weekly",
      max_daily_trips = null,
    } = payload;

    if (!phone || !fleet_owner_id || !fleet_vehicle_id) {
      return new Response(
        JSON.stringify({ error: "phone, fleet_owner_id, fleet_vehicle_id are required" }),
        { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    // Validate fleet owner is active
    const { data: owner, error: ownerErr } = await supabaseAdmin
      .from("fleet_owners")
      .select("id, is_active, subscription_expiry")
      .eq("id", fleet_owner_id)
      .single();

    if (ownerErr || !owner || !owner.is_active) {
      return new Response(
        JSON.stringify({ error: "Fleet owner not found or inactive" }),
        { status: 403, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    // Get vehicle plate for SMS
    const { data: vehicle } = await supabaseAdmin
      .from("fleet_vehicles")
      .select("plate_number")
      .eq("id", fleet_vehicle_id)
      .single();

    const platNumber = vehicle?.plate_number ?? "";

    // Check if phone already registered
    const { data: existingProfile } = await supabaseAdmin
      .from("profiles")
      .select("id, role")
      .eq("phone", phone)
      .single();

    let driverId: string;
    let isNewUser = false;

    if (existingProfile && existingProfile.role === "driver") {
      // Existing driver — link directly
      driverId = existingProfile.id;
    } else if (existingProfile) {
      return new Response(
        JSON.stringify({ error: "Phone is registered with a non-driver role" }),
        { status: 409, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    } else {
      // New user — create auth account + profile + driver record
      isNewUser = true;
      const tempPassword = generateTempPassword();

      const { data: authUser, error: authErr } = await supabaseAdmin.auth.admin.createUser({
        phone,
        password: tempPassword,
        phone_confirm: true,
      });

      if (authErr || !authUser.user) {
        return new Response(
          JSON.stringify({ error: "Failed to create auth user: " + authErr?.message }),
          { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
        );
      }

      driverId = authUser.user.id;

      // Create profile
      await supabaseAdmin.from("profiles").insert({
        id: driverId,
        phone,
        role: "driver",
      });

      // Create driver record
      await supabaseAdmin.from("drivers").insert({
        id: driverId,
        fleet_owner_id,
        is_fleet_driver: true,
      });

      // Send SMS with credentials
      const smsBody = `Wedit: تم تعيينك سائقاً للسيارة ${platNumber}. حمل التطبيق وسجل الدخول برقم هاتفك. كلمة المرور المؤقتة: ${tempPassword}`;
      await supabaseAdmin.functions.invoke("send-sms", {
        body: { phone, message: smsBody },
      });
    }

    // Update driver's fleet_owner_id if existing
    if (!isNewUser) {
      await supabaseAdmin
        .from("drivers")
        .update({ fleet_owner_id, is_fleet_driver: true })
        .eq("id", driverId);
    }

    // Create assignment (upsert by vehicle to replace any old assignment)
    const { error: assignErr } = await supabaseAdmin
      .from("fleet_driver_assignments")
      .upsert({
        fleet_owner_id,
        fleet_vehicle_id,
        driver_id: driverId,
        revenue_share_type,
        revenue_share_value,
        settlement_cycle,
        max_daily_trips,
        is_active: true,
      }, { onConflict: "fleet_vehicle_id" });

    if (assignErr) {
      return new Response(
        JSON.stringify({ error: "Failed to create assignment: " + assignErr.message }),
        { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    // Send FCM to driver if they have a token
    const { data: driverProfile } = await supabaseAdmin
      .from("profiles")
      .select("fcm_token")
      .eq("id", driverId)
      .single();

    if (driverProfile?.fcm_token) {
      await supabaseAdmin.functions.invoke("send-notification", {
        body: {
          user_id: driverId,
          title: "تعيين جديد",
          body: `تم تعيينك سائقاً للسيارة ${platNumber}`,
          type: "general",
          data: { fleet_vehicle_id, fleet_owner_id },
        },
      });
    }

    return new Response(
      JSON.stringify({ success: true, driver_id: driverId, is_new_user: isNewUser }),
      { status: 200, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
    );
  }
});
