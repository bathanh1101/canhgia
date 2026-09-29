import { z } from "zod";

/** 1250 bps → "12,5" (vi-VN decimal comma, max 2 decimals). */
export function bpsToPercent(bps: number): string {
  return String(bps / 100).replace(".", ",");
}

/** "12,5" | "12.5" | 12.5 → 1250. null when not a number in [0, 100] or finer than 0.01%. */
export function percentToBps(input: string | number): number | null {
  const s = typeof input === "number" ? String(input) : input.trim().replace(",", ".");
  if (!/^\d{1,3}(\.\d{1,2})?$/.test(s)) return null;
  const bps = Math.round(Number(s) * 100);
  return bps >= 0 && bps <= 10_000 ? bps : null;
}

/** SQL rejects share + max VIP bonus > 100%; check early to give a precise message. */
export function maxShareBps(tiers: { bonus_bps: number }[]): number {
  return 10_000 - Math.max(0, ...tiers.map((t) => t.bonus_bps));
}

const percent = z.string().transform((s, ctx) => {
  const bps = percentToBps(s);
  if (bps === null) ctx.addIssue({ code: "custom", message: "Nhập phần trăm từ 0 đến 100 (tối đa 2 số thập phân)" });
  return bps ?? 0;
});

export const ruleFormSchema = z.object({
  merchantId: z.string().max(64).nullable(),
  categoryKey: z.string().trim().max(64).nullable(),
  sharePercent: percent,
  enabled: z.boolean(),
  note: z.string().trim().max(200).default(""),
});
export type RuleForm = z.input<typeof ruleFormSchema>;

export const tierFormSchema = z.object({
  code: z.string().min(1).max(32),
  bonusPercent: percent,
  minGmv: z.string().trim().regex(/^\d{1,13}$/, "Nhập số nguyên VND").transform(Number),
});

export const simulatorSchema = z.object({
  merchantId: z.string().min(1).max(64),
  categoryKey: z.string().trim().max(64),
  orderValue: z.string().trim().regex(/^\d{1,12}$/, "Giá trị đơn không hợp lệ").transform(Number).refine((n) => n > 0, "Giá trị đơn phải lớn hơn 0"),
  tierCode: z.string().min(1).max(32),
});

export interface MerchantRef { id: string; name: string }
export interface CommissionRow { merchant_id: string; category_key: string; commission_rate_bps: number }
export interface RuleRecord { merchant_id: string | null; category_key: string | null; user_share_bps: number }

export interface RuleRow {
  key: string;
  merchantId: string | null;
  merchantName: string;
  categoryKey: string | null;
  commissionBps: number | null;
  ownShareBps: number | null;
  shareBps: number;
  /** share this row would use without its own rule (used when toggling back on) */
  inheritedBps: number;
  enabled: boolean;
}

/** Mirrors private.share_bps: (merchant,category) > (merchant,*) > (*,category) > (*,*) > 0. */
export function effectiveShare(rules: RuleRecord[], merchantId: string | null, category: string | null, skipOwn = false): number {
  const find = (m: string | null, c: string | null) =>
    rules.find((r) => r.merchant_id === m && r.category_key === c)?.user_share_bps;
  const chain = [
    skipOwn ? undefined : find(merchantId, category),
    category !== null ? find(merchantId, null) : undefined,
    merchantId !== null && category !== null ? find(null, category) : undefined,
    find(null, null),
  ];
  return chain.find((v) => v !== undefined) ?? 0;
}

/** Global default row, then per merchant: whole-campaign row + one row per category. */
export function buildRuleRows(merchants: MerchantRef[], commissions: CommissionRow[], rules: RuleRecord[]): RuleRow[] {
  const mk = (m: MerchantRef | null, cat: string | null, commissionBps: number | null): RuleRow => {
    const own = rules.find((r) => r.merchant_id === (m?.id ?? null) && r.category_key === cat)?.user_share_bps ?? null;
    const shareBps = effectiveShare(rules, m?.id ?? null, cat);
    return {
      key: `${m?.id ?? "*"}/${cat ?? "*"}`, merchantId: m?.id ?? null, merchantName: m?.name ?? "Mặc định toàn hệ thống",
      categoryKey: cat, commissionBps, ownShareBps: own, shareBps,
      inheritedBps: effectiveShare(rules, m?.id ?? null, cat, true), enabled: shareBps > 0,
    };
  };
  const out: RuleRow[] = [mk(null, null, null)];
  for (const m of merchants) {
    const mine = commissions.filter((c) => c.merchant_id === m.id);
    const cats = new Set<string>(mine.filter((c) => c.category_key !== "").map((c) => c.category_key));
    rules.filter((r) => r.merchant_id === m.id && r.category_key).forEach((r) => cats.add(r.category_key as string));
    out.push(mk(m, null, mine.find((c) => c.category_key === "")?.commission_rate_bps ?? null));
    for (const c of [...cats].sort()) out.push(mk(m, c, mine.find((x) => x.category_key === c)?.commission_rate_bps ?? null));
  }
  return out;
}
