// =============================================================
// Edge Function: admin-adjust-driver
// Admin tool to manually adjust a driver's gamification state:
// subscription days, reward points, XP, level, achievements, etc.
// Auth: admin JWT required (profiles.role = 'admin').
// =============================================================
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const JSON_HEADERS = { ...CORS_HEADERS, "Content-Type": "application/json" };

type ActionType =
  | "grant_sub_days"
  | "revoke_sub_days"
  | "grant_reward_points"
  | "deduct_reward_points"
  | "grant_xp"
  | "deduct_xp"
  | "grant_prize"
  | "freeze_override"
  | "unfreeze_override"
  | "level_override"
  | "achievement_grant"
  | "other";

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

  // 1. Authenticate and verify admin role
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

  const svc = createClient(supabaseUrl, serviceRoleKey);

  const { data: adminProfile } = await svc
    .from("profiles")
    .select("role")
    .eq("id", user.id)
    .single();

  if (!adminProfile || adminProfile.role !== "admin") {
    return new Response(JSON.stringify({ error: "غير مصرح — يتطلب صلاحيات المشرف" }), {
      status: 403,
      headers: JSON_HEADERS,
    });
  }

  let body: {
    driver_id:   string;
    action_type: ActionType;
    value:       number;
    reason:      string;
    extra?:      Record<string, unknown>;
  };
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "جسم الطلب غير صالح" }), {
      status: 400,
      headers: JSON_HEADERS,
    });
  }

  const { driver_id, action_type, value, reason, extra = {} } = body;

  if (!driver_id || !action_type || value === undefined || !reason) {
    return new Response(
      JSON.stringify({ error: "الحقول المطلوبة: driver_id, action_type, value, reason" }),
      { status: 400, headers: JSON_HEADERS }
    );
  }

  try {
    let beforeValue: unknown = null;
    let afterValue:  unknown = null;

    switch (action_type) {

      // ── Subscription day adjustments ──────────────────────────
      case "grant_sub_days":
      case "revoke_sub_days": {
        const { data: sub } = await svc
          .from("driver_subscriptions")
          .select("id, ends_at, no_expiry")
          .eq("driver_id", driver_id)
          .eq("status", "active")
          .maybeSingle();

        if (!sub) {
          return new Response(JSON.stringify({ error: "لا يوجد اشتراك نشط للسائق" }), {
            status: 400,
            headers: JSON_HEADERS,
          });
        }

        beforeValue = sub.ends_at;

        if (sub.ends_at && !sub.no_expiry) {
          const days      = action_type === "grant_sub_days" ? value : -value;
          const newEndsAt = new Date(sub.ends_at as string);
          newEndsAt.setUTCDate(newEndsAt.getUTCDate() + days);
          afterValue = newEndsAt.toISOString();

          await svc
            .from("driver_subscriptions")
            .update({ ends_at: afterValue })
            .eq("id", sub.id);
        }
        break;
      }

      // ── Reward points ──────────────────────────────────────────
      case "grant_reward_points": {
        const { data: profileRow } = await svc
          .from("profiles")
          .select("points")
          .eq("id", driver_id)
          .single();

        beforeValue = profileRow?.points ?? 0;
        afterValue  = (beforeValue as number) + value;

        await svc.from("profiles").update({ points: afterValue }).eq("id", driver_id);
        await svc.from("points_transactions").insert({
          user_id:     driver_id,
          amount:      value,
          type:        "bonus",
          description: reason,
        });
        break;
      }

      case "deduct_reward_points": {
        const { data: profileRow } = await svc
          .from("profiles")
          .select("points")
          .eq("id", driver_id)
          .single();

        beforeValue = profileRow?.points ?? 0;
        afterValue  = Math.max(0, (beforeValue as number) - value);

        await svc.from("profiles").update({ points: afterValue }).eq("id", driver_id);
        await svc.from("points_transactions").insert({
          user_id:     driver_id,
          amount:      -value,
          type:        "expiry",
          description: reason,
        });
        break;
      }

      // ── XP ────────────────────────────────────────────────────
      case "grant_xp": {
        const { data: levelState } = await svc
          .from("driver_level_state")
          .select("xp")
          .eq("driver_id", driver_id)
          .maybeSingle();

        beforeValue = levelState?.xp ?? 0;

        await svc.from("driver_xp_transactions").insert({
          driver_id:   driver_id,
          amount:      value,
          type:        "admin_grant",
          description: reason,
        });

        afterValue = (beforeValue as number) + value;
        break;
      }

      case "deduct_xp": {
        const { data: levelState } = await svc
          .from("driver_level_state")
          .select("xp")
          .eq("driver_id", driver_id)
          .maybeSingle();

        beforeValue = levelState?.xp ?? 0;

        await svc.from("driver_xp_transactions").insert({
          driver_id:   driver_id,
          amount:      -Math.abs(value),
          type:        "admin_deduct",
          description: reason,
        });

        afterValue = Math.max(0, (beforeValue as number) - value);
        break;
      }

      // ── Freeze override ────────────────────────────────────────
      case "freeze_override": {
        const { data: sub } = await svc
          .from("driver_subscriptions")
          .select("id, is_frozen, freeze_count_month, freeze_month_reset_at")
          .eq("driver_id", driver_id)
          .eq("status", "active")
          .maybeSingle();

        if (!sub) {
          return new Response(JSON.stringify({ error: "لا يوجد اشتراك نشط للسائق" }), {
            status: 400,
            headers: JSON_HEADERS,
          });
        }

        beforeValue = { is_frozen: sub.is_frozen };
        const frozenAt = new Date().toISOString();

        await svc.from("subscription_freezes").insert({
          driver_id:       driver_id,
          subscription_id: sub.id,
          custom_reason:   reason,
          frozen_at:       frozenAt,
        });

        await svc
          .from("driver_subscriptions")
          .update({ is_frozen: true, freeze_count_month: (sub.freeze_count_month as number ?? 0) + 1 })
          .eq("id", sub.id);

        await svc
          .from("driver_streaks")
          .update({ streak_frozen: true, streak_frozen_at: frozenAt })
          .eq("driver_id", driver_id);

        afterValue = { is_frozen: true };
        break;
      }

      // ── Unfreeze override ──────────────────────────────────────
      case "unfreeze_override": {
        const { data: freezeRecord } = await svc
          .from("subscription_freezes")
          .select("id, subscription_id, frozen_at")
          .eq("driver_id", driver_id)
          .is("unfrozen_at", null)
          .maybeSingle();

        if (!freezeRecord) {
          return new Response(JSON.stringify({ error: "لا يوجد تجميد نشط للسائق" }), {
            status: 400,
            headers: JSON_HEADERS,
          });
        }

        beforeValue = { is_frozen: true };
        const unfrozenAt   = new Date().toISOString();
        const secondsFrozen = (new Date(unfrozenAt).getTime() - new Date(freezeRecord.frozen_at as string).getTime()) / 1000;
        const frozenDays    = Math.ceil(secondsFrozen / 86400);

        await svc
          .from("subscription_freezes")
          .update({ unfrozen_at: unfrozenAt })
          .eq("id", freezeRecord.id);

        const { data: sub } = await svc
          .from("driver_subscriptions")
          .select("id, ends_at, frozen_days_total, no_expiry")
          .eq("id", freezeRecord.subscription_id)
          .single();

        const updatePayload: Record<string, unknown> = {
          is_frozen:         false,
          frozen_days_total: ((sub?.frozen_days_total as number) ?? 0) + frozenDays,
        };

        if (sub?.ends_at && !sub?.no_expiry) {
          const newEndsAt = new Date(sub.ends_at as string);
          newEndsAt.setUTCDate(newEndsAt.getUTCDate() + frozenDays);
          updatePayload.ends_at = newEndsAt.toISOString();
          afterValue = { is_frozen: false, new_ends_at: updatePayload.ends_at };
        } else {
          afterValue = { is_frozen: false };
        }

        await svc.from("driver_subscriptions").update(updatePayload).eq("id", freezeRecord.subscription_id);
        await svc.from("driver_streaks").update({ streak_frozen: false }).eq("driver_id", driver_id);
        break;
      }

      // ── Level override ─────────────────────────────────────────
      case "level_override": {
        const levelKey = extra.level_key as string;
        if (!levelKey) {
          return new Response(JSON.stringify({ error: "extra.level_key مطلوب لتغيير المستوى" }), {
            status: 400,
            headers: JSON_HEADERS,
          });
        }

        const { data: currentLevelState } = await svc
          .from("driver_level_state")
          .select("level_id")
          .eq("driver_id", driver_id)
          .maybeSingle();

        beforeValue = currentLevelState?.level_id;

        const { data: targetLevel, error: levelErr } = await svc
          .from("level_definitions")
          .select("id")
          .eq("level_key", levelKey)
          .single();

        if (levelErr || !targetLevel) {
          return new Response(JSON.stringify({ error: `مستوى غير معروف: ${levelKey}` }), {
            status: 400,
            headers: JSON_HEADERS,
          });
        }

        await svc
          .from("driver_level_state")
          .upsert({ driver_id, level_id: targetLevel.id }, { onConflict: "driver_id" });

        afterValue = targetLevel.id;
        break;
      }

      // ── Achievement grant ──────────────────────────────────────
      case "achievement_grant": {
        const achievementId = extra.achievement_id as string;
        if (!achievementId) {
          return new Response(JSON.stringify({ error: "extra.achievement_id مطلوب" }), {
            status: 400,
            headers: JSON_HEADERS,
          });
        }

        const { data: achievement, error: achErr } = await svc
          .from("achievements")
          .select("id, name_ar, reward_points, reward_xp")
          .eq("id", achievementId)
          .single();

        if (achErr || !achievement) {
          return new Response(JSON.stringify({ error: "الإنجاز غير موجود" }), {
            status: 404,
            headers: JSON_HEADERS,
          });
        }

        beforeValue = null;

        const { error: insertErr } = await svc.from("driver_achievements").insert({
          driver_id:      driver_id,
          achievement_id: achievementId,
          period_key:     null,
          earned_at:      new Date().toISOString(),
        });

        if (insertErr) {
          return new Response(
            JSON.stringify({ error: "فشل في منح الإنجاز (قد يكون مكتسباً بالفعل)", details: insertErr.message }),
            { status: 400, headers: JSON_HEADERS }
          );
        }

        // Apply rewards
        if (achievement.reward_points && (achievement.reward_points as number) > 0) {
          const { data: profileRow } = await svc
            .from("profiles")
            .select("points")
            .eq("id", driver_id)
            .single();

          const currentPoints = (profileRow?.points as number) ?? 0;
          await svc.from("profiles").update({ points: currentPoints + (achievement.reward_points as number) }).eq("id", driver_id);
          await svc.from("points_transactions").insert({
            user_id:     driver_id,
            amount:      achievement.reward_points,
            type:        "bonus",
            description: `مكافأة إنجاز: ${achievement.name_ar}`,
          });
        }

        if (achievement.reward_xp && (achievement.reward_xp as number) > 0) {
          await svc.from("driver_xp_transactions").insert({
            driver_id:   driver_id,
            amount:      achievement.reward_xp,
            type:        "achievement",
            description: `XP إنجاز: ${achievement.name_ar}`,
          });
        }

        afterValue = achievementId;
        break;
      }

      // ── Grant prize (box prize) ────────────────────────────────
      case "grant_prize": {
        const prizeId = extra.prize_id as string;
        if (!prizeId) {
          return new Response(JSON.stringify({ error: "extra.prize_id مطلوب" }), {
            status: 400,
            headers: JSON_HEADERS,
          });
        }

        const { data: prize, error: prizeErr } = await svc
          .from("box_prizes")
          .select("id, box_id, prize_type, value, description_ar, quantity_used")
          .eq("id", prizeId)
          .single();

        if (prizeErr || !prize) {
          return new Response(JSON.stringify({ error: "الجائزة غير موجودة" }), {
            status: 404,
            headers: JSON_HEADERS,
          });
        }

        beforeValue = null;

        // Create a delivered box opening record
        await svc.from("driver_box_openings").insert({
          driver_id:       driver_id,
          box_id:          prize.box_id,
          prize_id:        prizeId,
          prize_delivered: true,
          opened_at:       new Date().toISOString(),
        });

        await svc
          .from("box_prizes")
          .update({ quantity_used: ((prize.quantity_used as number) ?? 0) + 1 })
          .eq("id", prizeId);

        afterValue = { prize_id: prizeId, prize_type: prize.prize_type };
        break;
      }

      // ── Other (freeform note) ──────────────────────────────────
      case "other":
        beforeValue = null;
        afterValue  = { note: reason };
        break;

      default:
        return new Response(JSON.stringify({ error: `نوع الإجراء غير معروف: ${action_type}` }), {
          status: 400,
          headers: JSON_HEADERS,
        });
    }

    // 5. Insert audit log
    await svc.from("admin_audit_log").insert({
      admin_id:         user.id,
      target_driver_id: driver_id,
      action_type,
      before_value:     beforeValue,
      after_value:      afterValue,
      reason,
    });

    return new Response(
      JSON.stringify({
        success:      true,
        action_type,
        before_value: beforeValue,
        after_value:  afterValue,
      }),
      { status: 200, headers: JSON_HEADERS }
    );
  } catch (err) {
    console.error("admin-adjust-driver error:", err);
    return new Response(
      JSON.stringify({ error: "خطأ داخلي في الخادم", details: String(err) }),
      { status: 500, headers: JSON_HEADERS }
    );
  }
});
