"use server";

import { revalidatePath } from "next/cache";
import { fail, ok, type ActionResult } from "@/lib/admin/action-result";
import { requireAdmin } from "@/lib/admin/require-admin";
import { adjustAmountSchema, flagStatusSchema, kycDecisionSchema, reasonSchema, userIdSchema } from "./schemas";

const bad = () => fail({ message: "invalid_input" });
const refresh = (userId?: string) => {
  revalidatePath("/admin/users");
  if (userId) revalidatePath(`/admin/users/${userId}`);
};

export async function updateFlag(flagId: number, status: string): Promise<ActionResult> {
  const s = flagStatusSchema.safeParse(status);
  if (!Number.isSafeInteger(flagId) || flagId <= 0 || !s.success) return bad();
  const { supabase } = await requireAdmin();
  const { error } = await supabase.rpc("admin_update_flag", { p_flag_id: flagId, p_status: s.data });
  if (error) return fail(error);
  refresh();
  return ok(s.data === "dismissed" ? "Đã bỏ cảnh báo" : "Đã đánh dấu đã xử lý");
}

/** Lock needs a reason (SQL enforces it too); unlock passes an empty reason. */
export async function setUserLock(userId: string, locked: boolean, reason: string): Promise<ActionResult> {
  const id = userIdSchema.safeParse(userId);
  const r = locked ? reasonSchema.safeParse(reason) : { success: true as const, data: "" };
  if (!id.success || !r.success) return bad();
  const { supabase } = await requireAdmin();
  const { error } = await supabase.rpc("admin_set_user_lock", { p_user_id: id.data, p_locked: locked, p_reason: r.data });
  if (error) return fail(error);
  refresh(id.data);
  return ok(locked ? "Đã khóa tài khoản" : "Đã mở khóa tài khoản");
}

export async function reviewKyc(userId: string, decision: string, reason: string): Promise<ActionResult> {
  const id = userIdSchema.safeParse(userId);
  const d = kycDecisionSchema.safeParse(decision);
  const r = d.data === "rejected" ? reasonSchema.safeParse(reason) : { success: true as const, data: "" };
  if (!id.success || !d.success || !r.success) return bad();
  const { supabase } = await requireAdmin();
  const { error } = await supabase.rpc("admin_review_kyc", { p_user_id: id.data, p_decision: d.data, p_reason: r.data });
  if (error) return fail(error);
  refresh(id.data);
  return ok(d.data === "verified" ? "Đã duyệt KYC" : "Đã từ chối KYC");
}

export async function adjustWallet(userId: string, amount: number, reason: string): Promise<ActionResult> {
  const id = userIdSchema.safeParse(userId);
  const a = adjustAmountSchema.safeParse(amount);
  const r = reasonSchema.safeParse(reason);
  if (!id.success || !a.success || !r.success) return bad();
  const { supabase } = await requireAdmin();
  const { error } = await supabase.rpc("admin_adjust_wallet", { p_user_id: id.data, p_amount: a.data, p_reason: r.data });
  if (error) return fail(error);
  refresh(id.data);
  return ok("Đã điều chỉnh ví");
}
