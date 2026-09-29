"use server";

import { revalidatePath } from "next/cache";
import { type ActionResult, fail, ok } from "@/lib/admin/action-result";
import { requireAdmin } from "@/lib/admin/require-admin";
import { ruleFormSchema, simulatorSchema, tierFormSchema } from "@/components/admin/cashback-rules/rules-logic";
import { parseSettingValue } from "@/components/admin/cashback-rules/settings-logic";

const invalid = fail({ message: "invalid_input" });
const PATH = "/admin/cashback-rules";

// SQL treats null merchant as the global default row; generated arg types omit nullability.
const nullable = <T>(v: T | null) => v as T;

export async function upsertRule(input: unknown): Promise<ActionResult> {
  const { supabase } = await requireAdmin();
  const p = ruleFormSchema.safeParse(input);
  if (!p.success) return invalid;
  const { error } = await supabase.rpc("admin_upsert_cashback_rule", {
    p_merchant_id: nullable(p.data.merchantId),
    p_category_key: p.data.categoryKey ?? "",
    p_user_share_bps: p.data.sharePercent,
    p_enabled: p.data.enabled,
    p_note: p.data.note,
  });
  if (error) return fail(error);
  revalidatePath(PATH);
  return ok("Đã lưu tỷ lệ hoàn");
}

/** Off stores share 0; on restores the inherited share (`shareBps`, in bps). */
export async function toggleRule(
  merchantId: string | null, categoryKey: string | null, enabled: boolean, shareBps: number,
): Promise<ActionResult> {
  const { supabase } = await requireAdmin();
  if (!Number.isInteger(shareBps) || shareBps < 0 || shareBps > 10_000 || (enabled && shareBps === 0)) return invalid;
  const { error } = await supabase.rpc("admin_upsert_cashback_rule", {
    p_merchant_id: nullable(merchantId), p_category_key: categoryKey ?? "",
    p_user_share_bps: shareBps, p_enabled: enabled, p_note: enabled ? "bật lại" : "tắt",
  });
  if (error) return fail(error);
  revalidatePath(PATH);
  return ok(enabled ? "Đã bật tỷ lệ hoàn" : "Đã tắt hoàn tiền cho mục này");
}

export async function updateTier(input: unknown): Promise<ActionResult> {
  const { supabase } = await requireAdmin();
  const p = tierFormSchema.safeParse(input);
  if (!p.success) return invalid;
  const { error } = await supabase.rpc("admin_update_vip_tier", {
    p_code: p.data.code, p_bonus_bps: p.data.bonusPercent, p_min_gmv: p.data.minGmv,
  });
  if (error) return fail(error);
  revalidatePath(PATH);
  return ok("Đã cập nhật hạng VIP");
}

export interface SimResult {
  commission_vnd: number; base_cashback_vnd: number; vip_bonus_vnd: number; user_cashback_vnd: number;
  app_keeps_vnd: number; base_rate_bps: number; vip_rate_bps: number;
}

export async function simulate(input: unknown): Promise<ActionResult<SimResult>> {
  const { supabase } = await requireAdmin();
  const p = simulatorSchema.safeParse(input);
  if (!p.success) return invalid;
  const { data, error } = await supabase.rpc("estimate_cashback", {
    p_merchant_id: p.data.merchantId, p_category_key: p.data.categoryKey,
    p_order_value: p.data.orderValue, p_tier_code: p.data.tierCode,
  });
  if (error) return fail(error);
  const row = data?.[0];
  return row ? ok(undefined, row) : invalid;
}

export async function saveSetting(key: string, raw: Record<string, string>): Promise<ActionResult> {
  const { supabase } = await requireAdmin();
  const p = parseSettingValue(key, raw);
  if (!p.ok) return { ok: false, error: p.error };
  const { error } = await supabase.rpc("admin_set_setting", { p_key: key, p_value: p.value });
  if (error) return fail(error);
  revalidatePath(PATH);
  return ok("Đã lưu cấu hình");
}
