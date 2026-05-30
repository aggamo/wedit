// =============================================================
// Edge Function: fleet-expiry-warning
// Notifies fleet owners whose subscription expires in 7 days
// =============================================================
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 200 });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  const sevenDaysFromNow = new Date();
  sevenDaysFromNow.setDate(sevenDaysFromNow.getDate() + 7);
  const tomorrow = new Date();
  tomorrow.setDate(tomorrow.getDate() + 6);

  const { data: expiring } = await supabase
    .from("fleet_owners")
    .select("id, subscription_expiry")
    .eq("is_active", true)
    .gte("subscription_expiry", tomorrow.toISOString())
    .lte("subscription_expiry", sevenDaysFromNow.toISOString());

  for (const owner of expiring ?? []) {
    const expiryDate = new Date(owner.subscription_expiry).toLocaleDateString("ar-ET");
    await supabase.functions.invoke("send-notification", {
      body: {
        user_id: owner.id,
        title: "تنبيه: اشتراكك على وشك الانتهاء",
        body: `ينتهي اشتراكك في ${expiryDate}. جدد الآن للاستمرار في إدارة أسطولك.`,
        type: "subscription",
        data: { type: "fleet_expiry_warning", expiry: owner.subscription_expiry },
      },
    });
  }

  return new Response(JSON.stringify({ notified: expiring?.length ?? 0 }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
