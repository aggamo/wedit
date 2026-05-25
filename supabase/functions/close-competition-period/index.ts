// =============================================================
// Edge Function: close-competition-period
// Closes an active weekly/monthly competition period,
// assigns rank prizes, runs raffle, and opens a new period.
// =============================================================
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

interface CloseCompetitionRequest {
  period_type: "weekly" | "monthly";
}

interface PrizeEntry {
  rank:      number;
  cash:      number;
  free_days: number;
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

  let body: CloseCompetitionRequest;
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON body" }), {
      status: 400,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  }

  const { period_type } = body;

  if (!period_type || !["weekly", "monthly"].includes(period_type)) {
    return new Response(
      JSON.stringify({ error: "Invalid period_type. Must be 'weekly' or 'monthly'" }),
      { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
    );
  }

  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const supabase   = createClient(
    Deno.env.get("SUPABASE_URL")!,
    serviceKey
  );
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;

  try {
    // 1. Find the current active period
    const { data: activePeriod, error: periodError } = await supabase
      .from("competition_periods")
      .select("*")
      .eq("period_type", period_type)
      .eq("status", "active")
      .order("started_at", { ascending: false })
      .limit(1)
      .single();

    if (periodError || !activePeriod) {
      return new Response(
        JSON.stringify({ error: `No active ${period_type} period found`, details: periodError?.message }),
        { status: 404, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    // 2. Load competition settings
    const { data: settings, error: settingsError } = await supabase
      .from("competition_settings")
      .select("*")
      .eq("period_type", period_type)
      .single();

    if (settingsError || !settings) {
      return new Response(
        JSON.stringify({ error: "Competition settings not found" }),
        { status: 404, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    // 3. Run one final rankings refresh before closing
    const { error: refreshError } = await supabase.rpc("refresh_competition_rankings");
    if (refreshError) {
      console.error("Failed to refresh rankings:", refreshError);
      // Non-fatal; continue with existing rankings
    }

    // 4. Get final top rankings (all ranked drivers)
    const { data: finalRankings, error: rankingsError } = await supabase
      .from("competition_rankings")
      .select("rank, driver_id, score, rides_count, avg_rating")
      .eq("period_id", activePeriod.id)
      .order("rank", { ascending: true });

    if (rankingsError) {
      return new Response(
        JSON.stringify({ error: "Failed to fetch rankings", details: rankingsError.message }),
        { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    // 5. Close the current period
    const closedAt = new Date().toISOString();
    const { error: closeError } = await supabase
      .from("competition_periods")
      .update({
        status:           "closed",
        ended_at:         closedAt,
        settings_snapshot: settings,
      })
      .eq("id", activePeriod.id);

    if (closeError) {
      return new Response(
        JSON.stringify({ error: "Failed to close period", details: closeError.message }),
        { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    // 6. Create rank prize winners (top 3 by default, configurable via prizes array)
    const prizes: PrizeEntry[] = Array.isArray(settings.prizes)
      ? settings.prizes
      : [
          { rank: 1, cash: 500, free_days: 7 },
          { rank: 2, cash: 300, free_days: 0 },
          { rank: 3, cash: 150, free_days: 0 },
        ];

    const rankWinners: Array<{
      period_id:  string;
      driver_id:  string;
      win_type:   string;
      rank:       number;
      cash_prize: number;
      free_days:  number;
      is_paid:    boolean;
    }> = [];

    for (const prize of prizes) {
      const rankedDriver = finalRankings?.find((r) => r.rank === prize.rank);
      if (rankedDriver) {
        rankWinners.push({
          period_id:  activePeriod.id,
          driver_id:  rankedDriver.driver_id,
          win_type:   "rank_prize",
          rank:       prize.rank,
          cash_prize: prize.cash,
          free_days:  prize.free_days,
          is_paid:    false,
        });
      }
    }

    let insertedRankWinners: unknown[] = [];
    if (rankWinners.length > 0) {
      const { data: rankWinnerRows, error: winnerInsertError } = await supabase
        .from("competition_winners")
        .insert(rankWinners)
        .select();

      if (winnerInsertError) {
        console.error("Failed to insert rank winners:", winnerInsertError);
      } else {
        insertedRankWinners = rankWinnerRows ?? [];
      }
    }

    // 7. Run raffle (if enabled)
    let raffleResult: Record<string, unknown> = { skipped: "raffle_disabled" };
    if (settings.raffle_enabled) {
      const raffleResp = await fetch(`${supabaseUrl}/functions/v1/run-raffle`, {
        method: "POST",
        headers: {
          Authorization:  `Bearer ${serviceKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ period_id: activePeriod.id }),
      });

      if (raffleResp.ok) {
        raffleResult = await raffleResp.json();
      } else {
        const errText = await raffleResp.text();
        console.error("Raffle failed:", errText);
        raffleResult = { error: errText };
      }
    }

    // 8. Update period status to 'rewarded'
    await supabase
      .from("competition_periods")
      .update({ status: "rewarded" })
      .eq("id", activePeriod.id);

    // 9. Apply free subscription days to rank winners
    for (const winner of rankWinners.filter((w) => w.free_days > 0)) {
      const activeSub = await supabase
        .rpc("get_active_subscription", { p_driver_id: winner.driver_id })
        .single();

      if (activeSub.data) {
        const newEndDate = new Date(activeSub.data.ends_at);
        newEndDate.setDate(newEndDate.getDate() + winner.free_days);

        await supabase
          .from("driver_subscriptions")
          .update({ ends_at: newEndDate.toISOString() })
          .eq("id", activeSub.data.id);
      } else {
        // No active sub; create a free-days subscription
        const now     = new Date();
        const endDate = new Date(now);
        endDate.setDate(endDate.getDate() + winner.free_days);

        await supabase.from("driver_subscriptions").insert({
          driver_id:         winner.driver_id,
          plan:              "daily",
          amount:            0,
          status:            "active",
          started_at:        now.toISOString(),
          ends_at:           endDate.toISOString(),
          payment_method:    "bank",
          payment_reference: `competition-prize-${activePeriod.id}`,
          auto_renew:        false,
        });
      }
    }

    // 10. Notify rank prize winners
    const winnerDriverIds = rankWinners.map((w) => w.driver_id);
    const { data: winnerProfiles } = await supabase
      .from("profiles")
      .select("id, full_name, phone")
      .in("id", winnerDriverIds);

    const profileMap = new Map((winnerProfiles ?? []).map((p) => [p.id, p]));

    for (const winner of rankWinners) {
      const prize = prizes.find((p) => p.rank === winner.rank);
      if (!prize) continue;

      const periodLabel = period_type === "weekly" ? "weekly" : "monthly";

      await fetch(`${supabaseUrl}/functions/v1/send-notification`, {
        method: "POST",
        headers: {
          Authorization:  `Bearer ${serviceKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          user_id: winner.driver_id,
          title:   `#${winner.rank} in ${periodLabel} competition!`,
          body:    `Congratulations! You ranked #${winner.rank} in the ${periodLabel} competition! Prize: ${prize.cash} ETB${prize.free_days > 0 ? ` + ${prize.free_days} free subscription days` : ""}. Payment will be processed soon.`,
          type:    "leaderboard",
          data:    {
            period_id:   activePeriod.id,
            period_type,
            win_type:    "rank_prize",
            rank:        winner.rank,
            cash_prize:  prize.cash,
            free_days:   prize.free_days,
          },
        }),
      }).catch((err) => console.error(`Failed to notify rank winner ${winner.driver_id}:`, err));
    }

    // 11. Notify all other participants
    if (finalRankings && finalRankings.length > 0) {
      const nonWinnerIds = finalRankings
        .filter((r) => !winnerDriverIds.includes(r.driver_id))
        .slice(0, 50) // Limit to top 50 for notifications
        .map((r) => r.driver_id);

      for (const driverId of nonWinnerIds) {
        const driverRank = finalRankings.find((r) => r.driver_id === driverId);
        if (!driverRank) continue;

        await fetch(`${supabaseUrl}/functions/v1/send-notification`, {
          method: "POST",
          headers: {
            Authorization:  `Bearer ${serviceKey}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            user_id: driverId,
            title:   `${period_type === "weekly" ? "Weekly" : "Monthly"} competition ended`,
            body:    `The ${period_type} competition has ended. Your final rank: #${driverRank.rank}. Keep driving to win next time!`,
            type:    "leaderboard",
            data:    {
              period_id:   activePeriod.id,
              period_type,
              final_rank:  driverRank.rank,
              final_score: driverRank.score,
            },
          }),
        }).catch(() => {/* non-critical */});
      }
    }

    // 12. Create the next period
    const nextPeriodStart = new Date(closedAt);
    // For weekly: start next Monday; for monthly: start first of next month
    let newPeriod: { period_type: string; started_at: string; status: string };
    if (period_type === "weekly") {
      // Start next Monday
      const dayOfWeek = nextPeriodStart.getUTCDay(); // 0=Sun
      const daysUntilMonday = dayOfWeek === 1 ? 7 : (8 - dayOfWeek) % 7 || 7;
      const nextMonday = new Date(nextPeriodStart);
      nextMonday.setUTCDate(nextPeriodStart.getUTCDate() + daysUntilMonday);
      nextMonday.setUTCHours(0, 0, 0, 0);
      newPeriod = {
        period_type: "weekly",
        started_at:  nextMonday.toISOString(),
        status:      "active",
      };
    } else {
      // Start first day of next month
      const nextMonth = new Date(
        Date.UTC(nextPeriodStart.getUTCFullYear(), nextPeriodStart.getUTCMonth() + 1, 1)
      );
      newPeriod = {
        period_type: "monthly",
        started_at:  nextMonth.toISOString(),
        status:      "active",
      };
    }

    const { data: createdPeriod, error: createPeriodError } = await supabase
      .from("competition_periods")
      .insert(newPeriod)
      .select()
      .single();

    if (createPeriodError) {
      console.error("Failed to create next period:", createPeriodError);
    }

    console.log(
      `Closed ${period_type} period ${activePeriod.id}. Winners: ${rankWinners.length} rank prizes. Next period: ${createdPeriod?.id}`
    );

    return new Response(
      JSON.stringify({
        success:         true,
        closed_period:   activePeriod.id,
        period_type,
        rank_winners:    insertedRankWinners,
        raffle:          raffleResult,
        next_period:     createdPeriod ?? null,
        total_drivers:   finalRankings?.length ?? 0,
      }),
      { status: 200, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
    );
  } catch (err) {
    console.error("close-competition-period error:", err);
    return new Response(
      JSON.stringify({ error: "Internal server error", details: String(err) }),
      { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
    );
  }
});
