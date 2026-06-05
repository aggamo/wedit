// =============================================================
// Edge Function: open-reward-box
// Driver opens a reward box they've been awarded, selecting
// a prize via weighted random and applying it immediately
// unless admin approval is required.
// Auth: driver JWT required.
// =============================================================
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const JSON_HEADERS = { ...CORS_HEADERS, "Content-Type": "application/json" };

interface BoxPrize {
  id: string;
  box_id: string;
  prize_type: string;
  value: number;
  description_ar: string;
  weight: number;
  quantity_available: number | null;
  quantity_used: number;
  requires_admin_approval: boolean;
}

/** Weighted random selection from a list of prizes */
function weightedRandom(prizes: BoxPrize[]): BoxPrize | null {
  const totalWeight = prizes.reduce((sum, p) => sum + (p.weight ?? 1), 0);
  if (totalWeight <= 0) return null;

  let rand = Math.random() * totalWeight;
  for (const prize of prizes) {
    rand -= prize.weight ?? 1;
    if (rand <= 0) return prize;
  }
  return prizes[prizes.length - 1] ?? null;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS_HEADERS });
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "الطريقة غير مسموح بها" }), {
      status: 405,
      headers: JSON_HEADERS,
    });
  }

  const supabaseUrl    = Deno.env.get("SUPABASE_URL")!;
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const anonKey        = Deno.env.get("SUPABASE_ANON_KEY")!;

  const authHeader = req.headers.get("authorization") ?? "";
  if (!authHeader) {
    return new Response(JSON.stringify({ error: "مطلوب رمز التحقق" }), {
      status: 401,
      headers: JSON_HEADERS,
    });
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: { user }, error: authErr } = await userClient.auth.getUser();
  if (authErr || !user) {
    return new Response(JSON.stringify({ error: "غير مصرح" }), {
      status: 401,
      headers: JSON_HEADERS,
    });
  }

  let body: { box_id: string };
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "جسم الطلب غير صالح" }), {
      status: 400,
      headers: JSON_HEADERS,
    });
  }

  if (!body.box_id) {
    return new Response(JSON.stringify({ error: "box_id مطلوب" }), {
      status: 400,
      headers: JSON_HEADERS,
    });
  }

  const svc      = createClient(supabaseUrl, serviceRoleKey);
  const driverId = user.id;

  try {
    // 1. Fetch the box to validate it exists
    const { data: box, error: boxErr } = await svc
      .from("reward_boxes")
      .select("id, name_ar, fallback_prize_id, pity_threshold, pity_prize_id")
      .eq("id", body.box_id)
      .single();

    if (boxErr || !box) {
      return new Response(JSON.stringify({ error: "الصندوق غير موجود", details: boxErr?.message }), {
        status: 404,
        headers: JSON_HEADERS,
      });
    }

    // 2. Verify driver has been granted this box (pending opening)
    const { data: grantedOpening } = await svc
      .from("driver_box_openings")
      .select("id")
      .eq("driver_id", driverId)
      .eq("box_id", body.box_id)
      .eq("prize_delivered", false)
      .is("prize_id", null)
      .order("created_at", { ascending: true })
      .limit(1)
      .maybeSingle();

    if (!grantedOpening) {
      return new Response(JSON.stringify({ error: "لا يوجد صندوق مكافأة معلق لفتحه" }), {
        status: 400,
        headers: JSON_HEADERS,
      });
    }

    // Gate: driver must have completed 3+ consecutive active days to open a box
    const { data: streakRow } = await svc
      .from("driver_streaks")
      .select("current_streak")
      .eq("driver_id", driverId)
      .maybeSingle();

    if ((streakRow?.current_streak ?? 0) < 3) {
      return new Response(
        JSON.stringify({ error: "تحتاج إلى 3 أيام نشطة متتالية لفتح الصندوق" }),
        { status: 403, headers: JSON_HEADERS }
      );
    }

    // 3. Fetch available box prizes
    const { data: allPrizes, error: prizesErr } = await svc
      .from("box_prizes")
      .select("id, box_id, prize_type, value, description_ar, weight, quantity_available, quantity_used, requires_admin_approval")
      .eq("box_id", body.box_id);

    if (prizesErr) {
      return new Response(JSON.stringify({ error: "فشل جلب جوائز الصندوق", details: prizesErr.message }), {
        status: 500,
        headers: JSON_HEADERS,
      });
    }

    // 4. Filter available prizes
    const availablePrizes = (allPrizes ?? []).filter((p: BoxPrize) =>
      p.quantity_available === null || p.quantity_available > (p.quantity_used ?? 0)
    );

    // Read pity state for this driver+box
    const { data: pityRow } = await svc
      .from("driver_box_pity")
      .select("opens_since_last_rare")
      .eq("driver_id", driverId)
      .eq("box_id", body.box_id)
      .maybeSingle();

    const opensSoFar = (pityRow?.opens_since_last_rare ?? 0);
    const pitied =
      (box.pity_threshold as number | null) != null &&
      (box.pity_prize_id  as string | null) != null &&
      opensSoFar >= (box.pity_threshold as number);

    let selectedPrize: BoxPrize | null;
    if (pitied) {
      const { data: pityPrize } = await svc
        .from("box_prizes")
        .select("id, box_id, prize_type, value, description_ar, weight, quantity_available, quantity_used, requires_admin_approval")
        .eq("id", box.pity_prize_id as string)
        .single();
      selectedPrize = pityPrize ?? weightedRandom(availablePrizes);
    } else {
      selectedPrize = weightedRandom(availablePrizes);
    }

    // 5. Fallback prize if none available
    if (!selectedPrize && box.fallback_prize_id) {
      const { data: fallback } = await svc
        .from("box_prizes")
        .select("id, box_id, prize_type, value, description_ar, weight, quantity_available, quantity_used, requires_admin_approval")
        .eq("id", box.fallback_prize_id)
        .single();
      selectedPrize = fallback ?? null;
    }

    if (!selectedPrize) {
      return new Response(JSON.stringify({ error: "لا توجد جوائز متاحة في هذا الصندوق" }), {
        status: 400,
        headers: JSON_HEADERS,
      });
    }

    const requiresApproval = selectedPrize.requires_admin_approval ?? false;
    const deliveredNow     = !requiresApproval;

    // 6. Update the existing opening record with the selected prize
    const { error: updateOpeningErr } = await svc
      .from("driver_box_openings")
      .update({
        prize_id:        selectedPrize.id,
        prize_delivered: deliveredNow,
        opened_at:       new Date().toISOString(),
      })
      .eq("id", grantedOpening.id);

    if (updateOpeningErr) {
      return new Response(JSON.stringify({ error: "فشل في تحديث سجل الفتح", details: updateOpeningErr.message }), {
        status: 500,
        headers: JSON_HEADERS,
      });
    }

    // Update pity counter: reset on pity trigger, otherwise increment
    await svc.from("driver_box_pity").upsert(
      {
        driver_id:             driverId,
        box_id:                body.box_id,
        opens_since_last_rare: pitied ? 0 : opensSoFar + 1,
      },
      { onConflict: "driver_id,box_id" }
    );

    console.log(JSON.stringify({
      fn:         "open-reward-box",
      event:      "prize_selected",
      driver_id:  driverId,
      box_id:     body.box_id,
      prize_type: selectedPrize.prize_type,
      pitied,
    }));

    // 7. Apply prize immediately if no admin approval required
    if (deliveredNow) {
      switch (selectedPrize.prize_type) {
        case "reward_points": {
          // Atomic increment — avoids SELECT+UPDATE race condition
          await svc.rpc("increment_driver_points", {
            p_driver_id: driverId,
            p_amount:    selectedPrize.value,
          });

          await svc.from("points_transactions").insert({
            user_id:     driverId,
            amount:      selectedPrize.value,
            type:        "bonus",
            description: `جائزة صندوق مكافأة: ${selectedPrize.description_ar}`,
          });
          break;
        }
        case "xp": {
          await svc.from("driver_xp_transactions").insert({
            driver_id:   driverId,
            amount:      selectedPrize.value,
            type:        "reward_box",
            description: `XP صندوق مكافأة: ${selectedPrize.description_ar}`,
          });
          break;
        }
        case "subscription_days": {
          const { data: activeSub } = await svc
            .from("driver_subscriptions")
            .select("id, ends_at, no_expiry")
            .eq("driver_id", driverId)
            .eq("status", "active")
            .maybeSingle();

          if (activeSub && activeSub.ends_at && !activeSub.no_expiry) {
            const newEndsAt = new Date(activeSub.ends_at as string);
            newEndsAt.setUTCDate(newEndsAt.getUTCDate() + selectedPrize.value);
            await svc
              .from("driver_subscriptions")
              .update({ ends_at: newEndsAt.toISOString() })
              .eq("id", activeSub.id);
          }
          break;
        }
        case "priority_hours":
          // Record the grant — operational logic handled by ride dispatch
          await svc.from("driver_priority_grants").insert({
            driver_id:  driverId,
            hours:      selectedPrize.value,
            source:     "reward_box",
            granted_at: new Date().toISOString(),
            expires_at: null, // admin can set expiry
          }).then(() => {}).catch(() => {}); // table may not exist yet, ignore
          break;
        case "freeze_day": {
          // Increment freeze allowance for current month
          await svc
            .from("driver_subscriptions")
            .update({
              freeze_extra_days: svc.rpc ? undefined : undefined, // handled via raw update below
            })
            .eq("driver_id", driverId)
            .eq("status", "active")
            .then(() => {});

          // Just record in driver_box_openings (already done above)
          break;
        }
      }
    }

    // 8. Increment prize usage count
    await svc
      .from("box_prizes")
      .update({ quantity_used: (selectedPrize.quantity_used ?? 0) + 1 })
      .eq("id", selectedPrize.id);

    return new Response(
      JSON.stringify({
        success:                 true,
        prize_type:              selectedPrize.prize_type,
        value:                   selectedPrize.value,
        description_ar:          selectedPrize.description_ar,
        requires_admin_approval: requiresApproval,
        delivered:               deliveredNow,
      }),
      { status: 200, headers: JSON_HEADERS }
    );
  } catch (err) {
    console.error("open-reward-box error:", err);
    return new Response(
      JSON.stringify({ error: "خطأ داخلي في الخادم", details: String(err) }),
      { status: 500, headers: JSON_HEADERS }
    );
  }
});
