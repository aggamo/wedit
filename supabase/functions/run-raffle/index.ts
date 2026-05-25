// =============================================================
// Edge Function: run-raffle
// Randomly selects raffle winners from eligible drivers
// =============================================================
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

interface RaffleRequest {
  period_id: string;
}

interface RaffleWinner {
  driver_id: string;
  full_name: string | null;
  phone:     string | null;
}

/**
 * Cryptographically secure Fisher-Yates shuffle using Web Crypto API.
 * Returns a new shuffled array (does not mutate input).
 */
function secureShuffleArray<T>(arr: T[]): T[] {
  const shuffled = [...arr];
  for (let i = shuffled.length - 1; i > 0; i--) {
    // Generate a random 32-bit integer
    const randBuffer = new Uint32Array(1);
    crypto.getRandomValues(randBuffer);
    const j = randBuffer[0] % (i + 1);
    [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
  }
  return shuffled;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: CORS_HEADERS });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  }

  let body: RaffleRequest;
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON body" }), {
      status: 400,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  }

  const { period_id } = body;

  if (!period_id) {
    return new Response(
      JSON.stringify({ error: "Missing required field: period_id" }),
      { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
    );
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  try {
    // 1. Fetch the competition period
    const { data: period, error: periodError } = await supabase
      .from("competition_periods")
      .select("*")
      .eq("id", period_id)
      .single();

    if (periodError || !period) {
      return new Response(
        JSON.stringify({ error: "Competition period not found", details: periodError?.message }),
        { status: 404, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    // 2. Fetch competition settings for the period type
    const { data: settings, error: settingsError } = await supabase
      .from("competition_settings")
      .select("*")
      .eq("period_type", period.period_type)
      .single();

    if (settingsError || !settings) {
      return new Response(
        JSON.stringify({ error: "Competition settings not found" }),
        { status: 404, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    // Check if raffle is enabled
    if (!settings.raffle_enabled) {
      return new Response(
        JSON.stringify({ success: true, winners: [], message: "Raffle is disabled for this period type" }),
        { status: 200, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    const winnersCount = settings.raffle_winners_count as number ?? 1;

    // 3. Check for existing raffle winners (idempotency check)
    const { data: existingWinners } = await supabase
      .from("competition_winners")
      .select("id")
      .eq("period_id", period_id)
      .eq("win_type", "raffle");

    if (existingWinners && existingWinners.length > 0) {
      return new Response(
        JSON.stringify({
          success: true,
          message: "Raffle already ran for this period",
          existing_winners_count: existingWinners.length,
        }),
        { status: 200, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    // 4. Get all raffle-eligible drivers
    const { data: eligibleRankings, error: rankError } = await supabase
      .from("competition_rankings")
      .select("driver_id")
      .eq("period_id", period_id)
      .eq("is_raffle_eligible", true);

    if (rankError) {
      return new Response(
        JSON.stringify({ error: "Failed to fetch eligible drivers", details: rankError.message }),
        { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    if (!eligibleRankings || eligibleRankings.length === 0) {
      return new Response(
        JSON.stringify({ success: true, winners: [], message: "No eligible drivers for raffle" }),
        { status: 200, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    // 5. Shuffle and pick winners
    const shuffled = secureShuffleArray(eligibleRankings);
    const selectedWinners = shuffled.slice(0, Math.min(winnersCount, shuffled.length));

    // 6. Fetch profile info for winners
    const winnerIds = selectedWinners.map((w) => w.driver_id);
    const { data: winnerProfiles, error: profilesError } = await supabase
      .from("profiles")
      .select("id, full_name, phone")
      .in("id", winnerIds);

    if (profilesError) {
      console.error("Failed to fetch winner profiles:", profilesError);
    }

    const profileMap = new Map(
      (winnerProfiles ?? []).map((p) => [p.id, p])
    );

    // 7. Insert winner records
    const winnerInserts = selectedWinners.map((w) => ({
      period_id:  period_id,
      driver_id:  w.driver_id,
      win_type:   "raffle",
      cash_prize: settings.raffle_prize_cash ?? 1000,
      free_days:  settings.raffle_prize_days ?? 0,
      is_paid:    false,
    }));

    const { data: insertedWinners, error: insertError } = await supabase
      .from("competition_winners")
      .insert(winnerInserts)
      .select();

    if (insertError) {
      return new Response(
        JSON.stringify({ error: "Failed to insert winners", details: insertError.message }),
        { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    // 8. Notify each winner
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey  = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    const winnersResponse: RaffleWinner[] = [];

    for (const winnerId of winnerIds) {
      const profile = profileMap.get(winnerId);
      winnersResponse.push({
        driver_id: winnerId,
        full_name: profile?.full_name ?? null,
        phone:     profile?.phone ?? null,
      });

      // Send push notification
      await fetch(`${supabaseUrl}/functions/v1/send-notification`, {
        method: "POST",
        headers: {
          Authorization:  `Bearer ${serviceKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          user_id: winnerId,
          title:   "Congratulations! You won the raffle!",
          body:    `You are a raffle winner for the ${period.period_type} competition! Prize: ${settings.raffle_prize_cash} ETB${settings.raffle_prize_days > 0 ? ` + ${settings.raffle_prize_days} free days` : ""}. We will contact you shortly.`,
          type:    "leaderboard",
          data:    {
            period_id:   period_id,
            period_type: period.period_type,
            win_type:    "raffle",
            cash_prize:  settings.raffle_prize_cash,
            free_days:   settings.raffle_prize_days,
          },
        }),
      }).catch((err) => console.error(`Failed to notify winner ${winnerId}:`, err));
    }

    console.log(
      `Raffle completed for period ${period_id}: ${selectedWinners.length} winners selected from ${eligibleRankings.length} eligible`
    );

    return new Response(
      JSON.stringify({
        success:           true,
        winners:           winnersResponse,
        eligible_count:    eligibleRankings.length,
        winners_count:     selectedWinners.length,
        inserted_records:  insertedWinners?.length ?? 0,
      }),
      { status: 200, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
    );
  } catch (err) {
    console.error("run-raffle error:", err);
    return new Response(
      JSON.stringify({ error: "Internal server error", details: String(err) }),
      { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
    );
  }
});
