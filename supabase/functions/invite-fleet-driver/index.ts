// =============================================================
// Edge Function: invite-fleet-driver
// Invites a driver to a fleet owner's fleet on the Wedit
// ride-hailing platform (Addis Ababa, Ethiopia).
//
// Required environment variables (set in Supabase Dashboard):
//   SUPABASE_URL              - Your Supabase project URL
//   SUPABASE_SERVICE_ROLE_KEY - Service role key (bypasses RLS)
//
// Request body (JSON):
//   {
//     "fleet_owner_id": "uuid",
//     "phone":          "+251912345678",   // Ethiopian number, any format
//     "vehicle_id":     "uuid"             // optional
//   }
//
// The caller must be authenticated as the fleet owner
// (Authorization header must carry a JWT whose sub == fleet_owner_id).
// =============================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// ── Helpers ────────────────────────────────────────────────────────────────────

function jsonResponse(
  data: Record<string, unknown>,
  status = 200
): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

/** Normalise any Ethiopian phone number to E.164 +251XXXXXXXXX format */
function normalisePhone(raw: string): string {
  const digits = raw.replace(/\D/g, "");
  if (digits.startsWith("251")) return `+${digits}`;
  if (digits.startsWith("0"))   return `+251${digits.slice(1)}`;
  if (digits.length === 9)      return `+251${digits}`;
  return `+${digits}`;
}

/** Generate a temporary password like "WD483920" (prefix + 6 random digits) */
function generateTempPassword(): string {
  const digits = Math.floor(100000 + Math.random() * 900000).toString();
  return `WD${digits}`;
}

// ── Main handler ──────────────────────────────────────────────────────────────

serve(async (req: Request) => {
  // Handle CORS pre-flight
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: CORS_HEADERS });
  }

  const supabaseUrl  = Deno.env.get("SUPABASE_URL")!;
  const serviceKey   = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  // Service-role client for all DB operations (bypasses RLS)
  const supabase = createClient(supabaseUrl, serviceKey);

  // ── Parse & validate request body ─────────────────────────────────────────

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ success: false, error: "Invalid JSON body" }, 400);
  }

  const { fleet_owner_id, phone, vehicle_id } = body as {
    fleet_owner_id?: string;
    phone?: string;
    vehicle_id?: string;
  };

  if (!fleet_owner_id || !phone) {
    return jsonResponse(
      { success: false, error: "fleet_owner_id and phone are required" },
      422
    );
  }

  // ── Authenticate caller as the fleet owner ────────────────────────────────

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return jsonResponse({ success: false, error: "Missing Authorization header" }, 401);
  }

  // Verify the JWT belongs to the claimed fleet_owner_id
  const userClient = createClient(supabaseUrl, Deno.env.get("SUPABASE_ANON_KEY") ?? serviceKey, {
    global: { headers: { Authorization: authHeader } },
  });

  const { data: { user }, error: authError } = await userClient.auth.getUser();

  if (authError || !user) {
    return jsonResponse({ success: false, error: "Unauthorized: invalid token" }, 401);
  }

  if (user.id !== fleet_owner_id) {
    return jsonResponse(
      { success: false, error: "Forbidden: caller is not the specified fleet owner" },
      403
    );
  }

  // ── Normalise phone ───────────────────────────────────────────────────────

  const normalisedPhone = normalisePhone(phone);

  // ── Look up profile by phone ──────────────────────────────────────────────

  try {
    const { data: profile, error: profileErr } = await supabase
      .from("profiles")
      .select("id, phone")
      .eq("phone", normalisedPhone)
      .maybeSingle();

    if (profileErr) {
      console.error("profiles lookup error:", profileErr.message);
      return jsonResponse(
        { success: false, error: `Database error: ${profileErr.message}` },
        500
      );
    }

    // ── Branch A: profile already exists (existing user) ─────────────────────

    if (profile) {
      const driverId: string = profile.id;

      // Check whether this driver is already in another fleet
      const { data: driverRow, error: driverErr } = await supabase
        .from("drivers")
        .select("id, fleet_owner_id")
        .eq("id", driverId)
        .maybeSingle();

      if (driverErr) {
        console.error("drivers lookup error:", driverErr.message);
        return jsonResponse(
          { success: false, error: `Database error: ${driverErr.message}` },
          500
        );
      }

      if (
        driverRow &&
        driverRow.fleet_owner_id !== null &&
        driverRow.fleet_owner_id !== fleet_owner_id
      ) {
        return jsonResponse(
          {
            success: false,
            error: "Driver is already assigned to another fleet owner",
          },
          409
        );
      }

      // Insert accepted invitation record
      const { error: inviteErr } = await supabase
        .from("fleet_driver_invitations")
        .insert({
          status:            "accepted",
          fleet_owner_id,
          phone:             normalisedPhone,
          invited_driver_id: driverId,
          vehicle_id:        vehicle_id ?? null,
        });

      if (inviteErr) {
        console.error("fleet_driver_invitations insert error:", inviteErr.message);
        return jsonResponse(
          { success: false, error: `Database error: ${inviteErr.message}` },
          500
        );
      }

      // Assign driver to this fleet (upsert-style: update if row exists)
      const { error: updateErr } = await supabase
        .from("drivers")
        .update({
          fleet_owner_id:   fleet_owner_id,
          fleet_vehicle_id: vehicle_id ?? null,
        })
        .eq("id", driverId);

      if (updateErr) {
        console.error("drivers update error:", updateErr.message);
        // Non-fatal — invitation already recorded; log and continue
      }

      // Notify driver via SMS (Arabic message for existing user)
      try {
        await fetch(`${supabaseUrl}/functions/v1/send-sms`, {
          method: "POST",
          headers: {
            "Content-Type":  "application/json",
            "Authorization": `Bearer ${serviceKey}`,
          },
          body: JSON.stringify({
            message_type: "fleet_driver_invite",
            phone_number: normalisedPhone,
            is_new_user:  false,
          }),
        });
      } catch (smsErr) {
        // SMS failure is non-fatal; invitation is already persisted
        console.warn("SMS notification failed (non-fatal):", smsErr);
      }

      return jsonResponse({
        success:    true,
        is_new_user: false,
        driver_id:  driverId,
      });
    }

    // ── Branch B: profile does NOT exist (new user) ───────────────────────────

    const tempPassword = generateTempPassword();

    const { error: inviteErr } = await supabase
      .from("fleet_driver_invitations")
      .insert({
        status:        "pending",
        fleet_owner_id,
        phone:         normalisedPhone,
        vehicle_id:    vehicle_id ?? null,
        temp_password: tempPassword,
      });

    if (inviteErr) {
      console.error(
        "fleet_driver_invitations insert error (new user):",
        inviteErr.message
      );
      return jsonResponse(
        { success: false, error: `Database error: ${inviteErr.message}` },
        500
      );
    }

    // NOTE: We do NOT create an auth.users record here.
    // Supabase phone-based OTP auth will create the account automatically
    // the first time the driver enters their number in the app.
    // The pending invitation is matched by phone number at that point.

    return jsonResponse({
      success:      true,
      is_new_user:  true,
      temp_password: tempPassword,
      note:         "User account will be created when they first log in",
    });
  } catch (err) {
    console.error("Unexpected error in invite-fleet-driver:", err);
    return jsonResponse(
      { success: false, error: String(err) },
      500
    );
  }
});
