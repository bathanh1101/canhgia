import type { ComplaintDetailData } from "@/components/admin/complaints/complaint-detail";
import type { createServerSupabase } from "@/lib/supabase/server";

type Db = Awaited<ReturnType<typeof createServerSupabase>>;
const DAY = 86_400_000;

export async function loadComplaint(db: Db, id: number): Promise<ComplaintDetailData | null | { error: string }> {
  const { data: r, error } = await db.from("missing_order_reports").select("*").eq("id", id).maybeSingle();
  if (error) return { error: error.message };
  if (!r) return null;

  const t = Date.parse(`${r.purchased_on}T00:00:00Z`);
  const [profile, merchant, approver, orders, clicks] = await Promise.all([
    db.from("profiles").select("email").eq("id", r.user_id).maybeSingle(),
    db.from("merchants").select("name").eq("id", r.merchant_id).maybeSingle(),
    r.first_approved_by ? db.from("profiles").select("email").eq("id", r.first_approved_by).maybeSingle() : Promise.resolve({ data: null, error: null }),
    r.order_code_norm
      ? db.from("admin_orders").select("id,source,transaction_id,value_vnd,user_id,credit_state").eq("merchant_id", r.merchant_id).eq("transaction_id_norm", r.order_code_norm)
      : Promise.resolve({ data: [], error: null }),
    db.from("clicks").select("id,source,status,created_at").eq("user_id", r.user_id).eq("merchant_id", r.merchant_id)
      .gte("created_at", new Date(t - 3 * DAY).toISOString()).lte("created_at", new Date(t + 4 * DAY).toISOString()).order("created_at").limit(50),
  ]);
  const failed = [profile, merchant, approver, orders, clicks].find((x) => x.error);
  if (failed?.error) return { error: failed.error.message };

  const signed = await Promise.all(r.image_paths.map(async (p) => {
    const s = await db.storage.from("complaints").createSignedUrl(p, 60);
    return s.error ? null : s.data.signedUrl;
  }));
  return {
    report: r,
    email: profile.data?.email ?? "", merchantName: merchant.data?.name ?? r.merchant_id, firstApproverEmail: approver.data?.email ?? null,
    images: signed.filter((u): u is string => !!u),
    sameCodeOrders: (orders.data ?? []).map((o) => ({ id: o.id ?? "", source: o.source ?? "", transaction_id: o.transaction_id, value_vnd: o.value_vnd ?? 0, user_id: o.user_id, credit_state: o.credit_state ?? "none" })),
    clicks: clicks.data ?? [],
  };
}
