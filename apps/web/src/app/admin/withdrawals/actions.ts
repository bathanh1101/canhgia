"use server";

import { revalidatePath } from "next/cache";
import { fail, ok, type ActionResult } from "@/lib/admin/action-result";
import { requireAdmin } from "@/lib/admin/require-admin";
import type { RowResult } from "@/components/admin/withdrawals/types";
import { idsSchema, reasonSchema, settingsSchema, transferRefSchema } from "./schemas";

const bad = () => fail({ message: "invalid_input" });
const refresh = () => revalidatePath("/admin/withdrawals");

function toResults(rows: { id: string; ok: boolean; error: string | null }[] | null): RowResult[] {
  return (rows ?? []).map((r) => ({ id: r.id, ok: r.ok, error: r.error }));
}

function bulkMessage(results: RowResult[], done: string): ActionResult<RowResult[]> {
  const okCount = results.filter((r) => r.ok).length;
  return ok(okCount === results.length ? done : `${okCount}/${results.length} yêu cầu thành công. Xem chi tiết từng dòng.`, results);
}

/** Claim one row (SQL: `for update skip locked`; fails `invalid_state` when someone else holds it). */
export async function claimWithdrawal(id: string): Promise<ActionResult<{ claimedAt: string }>> {
  const parsed = idsSchema.safeParse([id]);
  if (!parsed.success) return bad();
  const { supabase } = await requireAdmin();
  const { data, error } = await supabase.rpc("admin_claim_withdrawal", { p_id: id });
  if (error) return fail(error);
  refresh();
  return ok("Đã nhận xử lý", { claimedAt: data?.[0]?.claimed_at ?? new Date().toISOString() });
}

/** Bulk claim: one RPC per id so each row reports its own outcome. */
export async function claimWithdrawals(ids: string[]): Promise<ActionResult<RowResult[]>> {
  const parsed = idsSchema.safeParse(ids);
  if (!parsed.success) return bad();
  const { supabase } = await requireAdmin();
  const results: RowResult[] = [];
  for (const id of parsed.data) {
    const { error } = await supabase.rpc("admin_claim_withdrawal", { p_id: id });
    results.push({ id, ok: !error, error: error?.message ?? null });
  }
  refresh();
  return bulkMessage(results, "Đã nhận xử lý tất cả yêu cầu");
}

export async function markPaid(ids: string[], transferRef: string): Promise<ActionResult<RowResult[]>> {
  const parsedIds = idsSchema.safeParse(ids);
  const parsedRef = transferRefSchema.safeParse(transferRef);
  if (!parsedIds.success || !parsedRef.success) return bad();
  const { supabase } = await requireAdmin();
  const { data, error } = await supabase.rpc("admin_mark_paid", { p_ids: parsedIds.data, p_transfer_ref: parsedRef.data });
  if (error) return fail(error);
  refresh();
  return bulkMessage(toResults(data), "Đã đánh dấu đã chuyển khoản");
}

export async function rejectWithdrawals(ids: string[], reason: string): Promise<ActionResult<RowResult[]>> {
  const parsedIds = idsSchema.safeParse(ids);
  const parsedReason = reasonSchema.safeParse(reason);
  if (!parsedIds.success || !parsedReason.success) return bad();
  const { supabase } = await requireAdmin();
  const { data, error } = await supabase.rpc("admin_reject_withdrawals", { p_ids: parsedIds.data, p_reason: parsedReason.data });
  if (error) return fail(error);
  refresh();
  return bulkMessage(toResults(data), "Đã từ chối và hoàn tiền vào ví");
}

export async function verifyBankAccount(bankAccountId: string): Promise<ActionResult> {
  const parsed = idsSchema.safeParse([bankAccountId]);
  if (!parsed.success) return bad();
  const { supabase } = await requireAdmin();
  const { error } = await supabase.rpc("admin_verify_bank_account", { p_id: bankAccountId });
  if (error) return fail(error);
  refresh();
  return ok("Đã xác nhận tên chủ tài khoản");
}

/** Auto payout is a stored stub (no consumer); daily cap is enforced in SQL. */
export async function savePayoutSettings(input: { autoEnabled: boolean; autoLimit: number; dailyCap: number }): Promise<ActionResult> {
  const parsed = settingsSchema.safeParse(input);
  if (!parsed.success) return bad();
  const { supabase } = await requireAdmin();
  const entries = [
    ["auto_payout_enabled", parsed.data.autoEnabled],
    ["auto_payout_limit_vnd", parsed.data.autoLimit],
    ["withdraw_daily_cap_vnd", parsed.data.dailyCap],
  ] as const;
  for (const [key, value] of entries) {
    const { error } = await supabase.rpc("admin_set_setting", { p_key: key, p_value: value });
    if (error) return fail(error);
  }
  refresh();
  return ok("Đã lưu cài đặt");
}
