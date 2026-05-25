// =============================================================
// Edge Function: send-notification
// Sends FCM v1 push notification and records it in DB
// =============================================================
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

interface NotificationPayload {
  user_id: string;
  title: string;
  body: string;
  type?: string;
  data?: Record<string, unknown>;
}

interface FcmMessage {
  message: {
    token: string;
    notification: { title: string; body: string };
    data?: Record<string, string>;
    android?: {
      notification: {
        channel_id: string;
        priority: string;
      };
    };
    apns?: {
      payload: {
        aps: {
          sound: string;
          badge: number;
        };
      };
    };
  };
}

// Obtain an FCM access token via Google's OAuth2 service account flow
async function getFcmAccessToken(serviceAccountJson: string): Promise<string> {
  const serviceAccount = JSON.parse(serviceAccountJson);
  const now = Math.floor(Date.now() / 1000);

  // Build JWT header and claim set
  const header = { alg: "RS256", typ: "JWT" };
  const claimSet = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };

  const encode = (obj: unknown) =>
    btoa(JSON.stringify(obj))
      .replace(/\+/g, "-")
      .replace(/\//g, "_")
      .replace(/=+$/, "");

  const headerB64  = encode(header);
  const claimB64   = encode(claimSet);
  const signingInput = `${headerB64}.${claimB64}`;

  // Import private key
  const keyData = serviceAccount.private_key
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\n/g, "");

  const binaryKey = Uint8Array.from(atob(keyData), (c) => c.charCodeAt(0));
  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryKey,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(signingInput)
  );

  const sigB64 = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");

  const jwt = `${signingInput}.${sigB64}`;

  // Exchange JWT for access token
  const tokenResp = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  if (!tokenResp.ok) {
    const err = await tokenResp.text();
    throw new Error(`Failed to get FCM access token: ${err}`);
  }

  const tokenData = await tokenResp.json();
  return tokenData.access_token as string;
}

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: CORS_HEADERS });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  }

  try {
    const payload: NotificationPayload = await req.json();

    if (!payload.user_id || !payload.title || !payload.body) {
      return new Response(
        JSON.stringify({ error: "Missing required fields: user_id, title, body" }),
        { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    // Create Supabase admin client
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // 1. Fetch user FCM token
    const { data: profile, error: profileError } = await supabase
      .from("profiles")
      .select("id, fcm_token, preferred_language")
      .eq("id", payload.user_id)
      .single();

    if (profileError || !profile) {
      return new Response(
        JSON.stringify({ error: "User not found", details: profileError?.message }),
        { status: 404, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    // 2. Insert notification record regardless of FCM availability
    const notifType = payload.type ?? "general";
    const { data: notifRecord, error: notifError } = await supabase
      .from("notifications")
      .insert({
        user_id:  payload.user_id,
        title:    payload.title,
        body:     payload.body,
        type:     notifType,
        data:     payload.data ?? {},
        is_read:  false,
      })
      .select()
      .single();

    if (notifError) {
      console.error("Failed to insert notification:", notifError);
    }

    // 3. Send FCM push if token is available
    let fcmResult: Record<string, unknown> = { skipped: "no_fcm_token" };

    if (profile.fcm_token) {
      const serviceAccountJson = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON");
      const fcmProjectId        = Deno.env.get("FCM_PROJECT_ID");

      if (!serviceAccountJson || !fcmProjectId) {
        console.error("FCM_SERVICE_ACCOUNT_JSON or FCM_PROJECT_ID env vars missing");
        fcmResult = { skipped: "fcm_not_configured" };
      } else {
        try {
          const accessToken = await getFcmAccessToken(serviceAccountJson);

          // Convert data values to strings (FCM requirement)
          const fcmData: Record<string, string> = {};
          if (payload.data) {
            for (const [k, v] of Object.entries(payload.data)) {
              fcmData[k] = typeof v === "string" ? v : JSON.stringify(v);
            }
          }
          fcmData["type"]            = notifType;
          fcmData["notification_id"] = notifRecord?.id ?? "";

          const fcmMessage: FcmMessage = {
            message: {
              token: profile.fcm_token,
              notification: {
                title: payload.title,
                body:  payload.body,
              },
              data: fcmData,
              android: {
                notification: {
                  channel_id: "wedit_notifications",
                  priority:   "HIGH",
                },
              },
              apns: {
                payload: {
                  aps: {
                    sound: "default",
                    badge: 1,
                  },
                },
              },
            },
          };

          const fcmResp = await fetch(
            `https://fcm.googleapis.com/v1/projects/${fcmProjectId}/messages:send`,
            {
              method: "POST",
              headers: {
                Authorization:  `Bearer ${accessToken}`,
                "Content-Type": "application/json",
              },
              body: JSON.stringify(fcmMessage),
            }
          );

          if (!fcmResp.ok) {
            const errBody = await fcmResp.text();
            console.error("FCM error:", errBody);
            fcmResult = { error: "fcm_send_failed", details: errBody };
          } else {
            const fcmBody = await fcmResp.json();
            fcmResult = { success: true, message_id: fcmBody.name };
          }
        } catch (fcmErr) {
          console.error("FCM exception:", fcmErr);
          fcmResult = { error: "fcm_exception", details: String(fcmErr) };
        }
      }
    }

    return new Response(
      JSON.stringify({
        success:         true,
        notification_id: notifRecord?.id,
        fcm:             fcmResult,
      }),
      { status: 200, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
    );
  } catch (err) {
    console.error("send-notification error:", err);
    return new Response(
      JSON.stringify({ error: "Internal server error", details: String(err) }),
      { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
    );
  }
});
