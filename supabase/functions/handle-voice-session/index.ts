// =============================================================
// Edge Function: handle-voice-session
// Multi-step Africa's Talking Voice webhook for Amharic IVR.
//
// Required env vars:
//   SUPABASE_URL              — project URL
//   SUPABASE_SERVICE_ROLE_KEY — bypasses RLS
//   AI_CALL_WEBHOOK_SECRET    — shared secret (also used as AT secret)
//   GOOGLE_API_KEY            — covers Speech-to-Text + TTS + Geocoding
//   DIALOGFLOW_PROJECT_ID     — Dialogflow ES project
//   DIALOGFLOW_CREDENTIALS_JSON — base64-encoded service account JSON
//
// Request (step=incoming) — AT calls this when a call arrives:
//   POST body (form-encoded):
//     callerNumber, sessionId, callSessionState, dtmfDigits
//
// Request (step=recording) — AT calls this after recording:
//   POST body (form-encoded):
//     callSessionState, recordingUrl, durationInSeconds,
//     sessionId (= ai_call_logs.call_sid from earlier step)
//   Query param: log_id=<ai_call_logs.id>
//
// Response: Africa's Talking ActionXML
// =============================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ── AT ActionXML helpers ──────────────────────────────────────────────────────

function xmlResponse(content: string): Response {
  return new Response(
    `<?xml version="1.0" encoding="UTF-8"?><Response>${content}</Response>`,
    { status: 200, headers: { "Content-Type": "text/xml" } },
  );
}

function playThenHangup(audioUrl: string): string {
  return `<Play url="${audioUrl}"/><Reject/>`;
}

function playThenRecord(audioUrl: string, callbackUrl: string): string {
  return (
    `<Play url="${audioUrl}"/>` +
    `<Record maxLength="30" trimSilence="true" ` +
    `finishOnKey="#" callbackUrl="${encodeURI(callbackUrl)}"/>`
  );
}

function sayAmharic(text: string): string {
  return `<Say voice="Polly.Zeina">${text}</Say>`;
}

// ── Storage audio URLs (uploaded by setup script) ────────────────────────────

function audioUrl(supabaseUrl: string, file: string): string {
  return `${supabaseUrl}/storage/v1/object/public/ai-voice/${file}`;
}

// ── Google Speech-to-Text (Amharic) ──────────────────────────────────────────

async function transcribeAudio(
  audioUrl: string,
  googleApiKey: string,
): Promise<{ transcript: string; confidence: number } | null> {
  // 1. Download audio from Africa's Talking recording URL
  let audioBase64: string;
  try {
    const audioRes = await fetch(audioUrl);
    if (!audioRes.ok) {
      console.error("Audio download failed:", audioRes.status);
      return null;
    }
    const audioBuffer = await audioRes.arrayBuffer();
    audioBase64 = btoa(String.fromCharCode(...new Uint8Array(audioBuffer)));
  } catch (e) {
    console.error("Audio download error:", e);
    return null;
  }

  // 2. Send to Google STT
  const sttRes = await fetch(
    `https://speech.googleapis.com/v1/speech:recognize?key=${googleApiKey}`,
    {
      method:  "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        config: {
          encoding:        "LINEAR16",
          languageCode:    "am-ET",
          model:           "default",
          useEnhanced:     true,
          enableWordTimeOffsets: false,
        },
        audio: { content: audioBase64 },
      }),
    },
  );

  if (!sttRes.ok) {
    console.error("STT API error:", await sttRes.text());
    return null;
  }

  const sttData = await sttRes.json();
  const result = sttData?.results?.[0]?.alternatives?.[0];
  if (!result) return null;

  return {
    transcript: result.transcript as string,
    confidence: result.confidence as number ?? 0.5,
  };
}

// ── Google Geocoding ──────────────────────────────────────────────────────────

async function geocodeLocation(
  text: string,
  googleApiKey: string,
): Promise<{ lat: number; lng: number } | null> {
  // Bias results to Addis Ababa bounding box
  const addisCenter = "9.0280,38.7469";
  const url =
    `https://maps.googleapis.com/maps/api/geocode/json` +
    `?address=${encodeURIComponent(text + ", Addis Ababa, Ethiopia")}` +
    `&key=${googleApiKey}` +
    `&region=et` +
    `&location=${addisCenter}&radius=20000`;

  try {
    const res  = await fetch(url);
    const data = await res.json();
    if (data.status !== "OK" || !data.results?.[0]) return null;
    const loc = data.results[0].geometry.location;
    return { lat: loc.lat as number, lng: loc.lng as number };
  } catch (e) {
    console.error("Geocoding error:", e);
    return null;
  }
}

// ── Google Dialogflow ES — intent extraction ──────────────────────────────────

async function extractRideIntent(
  transcript: string,
  projectId: string,
  credentialsJson: string,
): Promise<{
  pickup:      string | null;
  destination: string | null;
  vehicleType: string;
} | null> {
  // Decode credentials and get access token
  let credentials: Record<string, unknown>;
  try {
    credentials = JSON.parse(atob(credentialsJson));
  } catch {
    console.error("Invalid DIALOGFLOW_CREDENTIALS_JSON");
    return null;
  }

  // Get Google OAuth2 token using service account
  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method:  "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion:  await buildJwt(credentials),
    }),
  });

  if (!tokenRes.ok) {
    console.error("OAuth token error:", await tokenRes.text());
    return null;
  }

  const { access_token } = await tokenRes.json();
  const sessionId = crypto.randomUUID();

  // Call Dialogflow detectIntent
  const dfRes = await fetch(
    `https://dialogflow.googleapis.com/v2/projects/${projectId}/agent/sessions/${sessionId}:detectIntent`,
    {
      method:  "POST",
      headers: {
        "Content-Type":  "application/json",
        "Authorization": `Bearer ${access_token}`,
      },
      body: JSON.stringify({
        queryInput: {
          text: { text: transcript, languageCode: "am" },
        },
      }),
    },
  );

  if (!dfRes.ok) {
    console.error("Dialogflow error:", await dfRes.text());
    return null;
  }

  const dfData = await dfRes.json();
  const params = dfData?.queryResult?.parameters as Record<string, unknown> | undefined;

  const vehicleMap: Record<string, string> = {
    "ሚኒቡስ": "minibus", "minibus": "minibus",
    "suv":   "suv",    "ትልቅ":   "suv",
    "vip":   "vip",
  };

  const rawVehicle = (params?.vehicle_type as string ?? "").toLowerCase();
  const vehicleType = vehicleMap[rawVehicle] ?? "sedan";

  return {
    pickup:      (params?.pickup_location as string) || null,
    destination: (params?.destination     as string) || null,
    vehicleType,
  };
}

// ── Minimal JWT builder for Google service account ────────────────────────────

async function buildJwt(credentials: Record<string, unknown>): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header  = btoa(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const payload = btoa(JSON.stringify({
    iss: credentials.client_email,
    sub: credentials.client_email,
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
    scope: "https://www.googleapis.com/auth/cloud-platform https://www.googleapis.com/auth/dialogflow",
  }));

  const pemKey = (credentials.private_key as string)
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\n/g, "");

  const keyData = Uint8Array.from(atob(pemKey), (c) => c.charCodeAt(0));
  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    keyData.buffer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );

  const data      = new TextEncoder().encode(`${header}.${payload}`);
  const signature = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", cryptoKey, data);
  const sigBase64 = btoa(String.fromCharCode(...new Uint8Array(signature)));

  return `${header}.${payload}.${sigBase64}`;
}

// ── Google TTS → Supabase Storage (dynamic confirmation audio) ───────────────

async function generateAndStoreConfirmation(
  text: string,
  googleApiKey: string,
  supabase: ReturnType<typeof createClient>,
  rideId: string,
): Promise<string | null> {
  try {
    const ttsRes = await fetch(
      `https://texttospeech.googleapis.com/v1/text:synthesize?key=${googleApiKey}`,
      {
        method:  "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          input:       { text },
          voice:       { languageCode: "am-ET", ssmlGender: "NEUTRAL" },
          audioConfig: { audioEncoding: "MP3" },
        }),
      },
    );

    if (!ttsRes.ok) return null;

    const { audioContent } = await ttsRes.json();
    const audioBytes = Uint8Array.from(atob(audioContent as string), (c) => c.charCodeAt(0));

    const fileName = `confirmations/${rideId}.mp3`;
    await supabase.storage.from("ai-voice").upload(fileName, audioBytes, {
      contentType: "audio/mpeg",
      upsert: true,
    });

    const { data } = supabase.storage.from("ai-voice").getPublicUrl(fileName);
    return data.publicUrl;
  } catch (e) {
    console.error("TTS/storage error:", e);
    return null;
  }
}

// ── Main handler ──────────────────────────────────────────────────────────────

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Methods": "POST, OPTIONS" },
    });
  }

  const url            = new URL(req.url);
  const step           = url.searchParams.get("step") ?? "incoming";
  const logId          = url.searchParams.get("log_id");

  const supabaseUrl    = Deno.env.get("SUPABASE_URL")!;
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const webhookSecret  = Deno.env.get("AI_CALL_WEBHOOK_SECRET") ?? "";
  const googleApiKey   = Deno.env.get("GOOGLE_API_KEY") ?? "";
  const dfProjectId    = Deno.env.get("DIALOGFLOW_PROJECT_ID") ?? "";
  const dfCredentials  = Deno.env.get("DIALOGFLOW_CREDENTIALS_JSON") ?? "";

  const svc = createClient(supabaseUrl, serviceRoleKey);

  // ── Parse Africa's Talking form body ───────────────────────────────────────
  let formData: Record<string, string> = {};
  try {
    const text   = await req.text();
    const params = new URLSearchParams(text);
    params.forEach((v, k) => { formData[k] = v; });
  } catch {
    return new Response("Bad request", { status: 400 });
  }

  const callerNumber  = formData["callerNumber"]  ?? formData["From"] ?? "";
  const sessionId     = formData["sessionId"]     ?? formData["CallSid"] ?? "";
  const recordingUrl  = formData["recordingUrl"]  ?? formData["RecordingUrl"] ?? "";

  // ── STEP: incoming — play greeting, start recording ───────────────────────
  if (step === "incoming") {
    // Create ai_call_logs entry
    const { data: logRow } = await svc
      .from("ai_call_logs")
      .insert({
        call_sid:        sessionId,
        passenger_phone: callerNumber,
        status:          "in_progress",
      })
      .select("id")
      .single();

    const newLogId    = logRow?.id as string ?? "unknown";
    const functionUrl = `${supabaseUrl}/functions/v1/handle-voice-session`;
    const callbackUrl = `${functionUrl}?step=recording&log_id=${newLogId}&secret=${webhookSecret}`;

    const greetingUrl = audioUrl(supabaseUrl, "greeting.mp3");

    return xmlResponse(playThenRecord(greetingUrl, callbackUrl));
  }

  // ── STEP: recording — transcribe, geocode, dispatch ───────────────────────
  if (step === "recording") {
    // Validate secret in query param (AT doesn't support custom headers)
    const secretParam = url.searchParams.get("secret") ?? "";
    if (webhookSecret && secretParam !== webhookSecret) {
      return new Response("Forbidden", { status: 403 });
    }

    if (!recordingUrl) {
      console.error("No recordingUrl in callback");
      return xmlResponse(playThenHangup(audioUrl(supabaseUrl, "error.mp3")));
    }

    // Fetch current retry count
    let retryCount = 0;
    if (logId) {
      const { data: logRow } = await svc
        .from("ai_call_logs")
        .select("retry_count")
        .eq("id", logId)
        .maybeSingle();
      retryCount = logRow?.retry_count ?? 0;
    }

    // Transcribe
    const sttResult = await transcribeAudio(recordingUrl, googleApiKey);
    console.log("STT result:", sttResult);

    if (!sttResult || sttResult.confidence < 0.70) {
      if (retryCount >= 2) {
        if (logId) await svc.from("ai_call_logs").update({ status: "failed" }).eq("id", logId);
        return xmlResponse(playThenHangup(audioUrl(supabaseUrl, "error.mp3")));
      }

      if (logId) {
        await svc.from("ai_call_logs").update({ retry_count: retryCount + 1 }).eq("id", logId);
      }

      const functionUrl = `${supabaseUrl}/functions/v1/handle-voice-session`;
      const callbackUrl = `${functionUrl}?step=recording&log_id=${logId}&secret=${webhookSecret}`;
      return xmlResponse(playThenRecord(audioUrl(supabaseUrl, "retry.mp3"), callbackUrl));
    }

    const transcript = sttResult.transcript;

    // Extract intent via Dialogflow
    const intent = await extractRideIntent(transcript, dfProjectId, dfCredentials);
    const pickupText  = intent?.pickup ?? transcript; // fallback: use full transcript
    const destText    = intent?.destination ?? "";
    const vehicleType = intent?.vehicleType ?? "sedan";

    // Geocode pickup location
    const pickupCoords = await geocodeLocation(pickupText, googleApiKey);

    if (!pickupCoords) {
      // Ask passenger to clarify location
      if (retryCount >= 2) {
        if (logId) await svc.from("ai_call_logs").update({ status: "failed" }).eq("id", logId);
        return xmlResponse(playThenHangup(audioUrl(supabaseUrl, "error.mp3")));
      }

      if (logId) {
        await svc.from("ai_call_logs").update({
          raw_transcript: transcript,
          pickup_text:    pickupText,
          retry_count:    retryCount + 1,
        }).eq("id", logId);
      }

      const functionUrl = `${supabaseUrl}/functions/v1/handle-voice-session`;
      const callbackUrl = `${functionUrl}?step=recording&log_id=${logId}&secret=${webhookSecret}`;
      return xmlResponse(playThenRecord(audioUrl(supabaseUrl, "location_unclear.mp3"), callbackUrl));
    }

    // Update log with extracted data
    if (logId) {
      await svc.from("ai_call_logs").update({
        raw_transcript:   transcript,
        pickup_text:      pickupText,
        destination_text: destText,
        pickup_lat:       pickupCoords.lat,
        pickup_lng:       pickupCoords.lng,
        vehicle_type:     vehicleType,
        confidence_score: sttResult.confidence,
      }).eq("id", logId);
    }

    // Dispatch ride via create-ai-ride
    const dispatchRes = await fetch(
      `${supabaseUrl}/functions/v1/create-ai-ride`,
      {
        method:  "POST",
        headers: {
          "Content-Type":    "application/json",
          "X-Wedit-Secret":  webhookSecret,
        },
        body: JSON.stringify({
          log_id:           logId,
          passenger_phone:  callerNumber,
          pickup_lat:       pickupCoords.lat,
          pickup_lng:       pickupCoords.lng,
          pickup_text:      pickupText,
          destination_text: destText,
          vehicle_type:     vehicleType,
          transcript,
          confidence_score: sttResult.confidence,
        }),
      },
    );

    const dispatchData = await dispatchRes.json();

    if (!dispatchData.success) {
      // No driver available
      return xmlResponse(playThenHangup(audioUrl(supabaseUrl, "no_driver.mp3")));
    }

    // Generate confirmation TTS
    const driverName  = dispatchData.driver_name as string ?? "";
    const etaMinutes  = dispatchData.eta_minutes as number ?? 5;
    const rideId      = dispatchData.ride_id as string ?? "";

    const confirmText = `ሹፌር ${driverName} በ${etaMinutes} ደቂቃ ይደርሳሉ። ቁጥሩ ${callerNumber}። ምስጋና ይቅርብልን!`;

    let confirmAudioUrl = await generateAndStoreConfirmation(
      confirmText,
      googleApiKey,
      svc,
      rideId,
    );

    // Fallback to static audio if TTS generation fails
    if (!confirmAudioUrl) {
      confirmAudioUrl = audioUrl(supabaseUrl, "driver_found.mp3");
    }

    return xmlResponse(playThenHangup(confirmAudioUrl));
  }

  // Unknown step
  return new Response("Unknown step", { status: 400 });
});
