"use server";

import { revalidatePath } from "next/cache";
import { resolveMessage } from "@/components/admin/complaints/complaint-state";
import { fail, ok, type ActionResult } from "@/lib/admin/action-result";
import { requireAdmin } from "@/lib/admin/require-admin";
import { amountSchema, decisionSchema, lookupResponseSchema, noteSchema, reportIdSchema, type LookupResponse } from "./schemas";

const bad = () => fail({ message: "invalid_input" });

/** approved: amount required (> 2.000.000đ goes through the second-approver flow); rejected: amount ignored, note required. */
export async function resolveComplaint(id: number, decision: string, amount: number, note: string): Promise<ActionResult<{ result: string }>> {
  const i = reportIdSchema.safeParse(id);
  const d = decisionSchema.safeParse(decision);
  const n = noteSchema.safeParse(note);
  const a = d.data === "approved" ? amountSchema.safeParse(amount) : { success: true as const, data: 0 };
  if (!i.success || !d.success || !n.success || !a.success) return bad();
  const { supabase } = await requireAdmin();
  const { data, error } = await supabase.rpc("admin_resolve_complaint", { p_id: i.data, p_decision: d.data, p_amount: a.data, p_note: n.data });
  if (error) return fail(error);
  revalidatePath("/admin/complaints");
  revalidatePath(`/admin/complaints/${i.data}`);
  return ok(resolveMessage(data, a.data), { result: data ?? "" });
}

/** AccessTrade lookup through the Edge Function with the admin's own session JWT. */
export async function lookupAccessTrade(id: number): Promise<ActionResult<LookupResponse>> {
  const i = reportIdSchema.safeParse(id);
  if (!i.success) return bad();
  const { supabase } = await requireAdmin();
  const { data: r, error: rErr } = await supabase.from("missing_order_reports")
    .select("merchant_id,order_code,purchased_on").eq("id", i.data).maybeSingle();
  if (rErr) return fail(rErr);
  if (!r) return fail({ message: "invalid_state" });

  const { data, error } = await supabase.functions.invoke("admin-at-lookup", {
    body: { merchant_id: r.merchant_id, order_code: r.order_code, purchased_on: r.purchased_on },
  });
  if (error) {
    const body = await (error as { context?: Response }).context?.json().catch(() => null);
    const code = (body as { error?: string } | null)?.error;
    if (code === "rate_limited") return { ok: false, error: "AccessTrade đang giới hạn tần suất tra cứu. Vui lòng thử lại sau ít phút." };
    return fail({ message: code ?? "" });
  }
  const parsed = lookupResponseSchema.safeParse(data);
  if (!parsed.success) return { ok: false, error: "Phản hồi tra cứu AccessTrade không hợp lệ." };
  return ok("Đã tra cứu AccessTrade", parsed.data);
}
