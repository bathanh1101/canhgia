import { z } from "zod";
import type { Json } from "@/lib/supabase/database.types";

export const NUMERIC_SETTINGS = {
  min_withdraw_vnd: "Rút tối thiểu (VND)",
  withdraw_daily_cap_vnd: "Hạn mức rút mỗi ngày (VND)",
  referral_bonus_vnd: "Thưởng giới thiệu tối đa (VND)",
  click_limit_per_hour: "Giới hạn click mỗi giờ",
} as const;
export type NumericSettingKey = keyof typeof NUMERIC_SETTINGS;

export const SETTING_KEYS = [...Object.keys(NUMERIC_SETTINGS), "withdraw_eta_text", "landing_stats"] as const;
export type SettingKey = (typeof SETTING_KEYS)[number];

const integer = z.string().trim().regex(/^\d{1,12}$/, "Nhập số nguyên không âm").transform(Number);
const eta = z.string().trim().min(1, "Không được để trống").max(100, "Tối đa 100 ký tự");

/** landing_stats shape (docs/web-admin-conventions.md): {rating?: number, users?: string, refunded?: string} | null. */
const landing = z.object({
  rating: z.string().trim().transform((s) => s.replace(",", ".")).pipe(
    z.union([z.literal(""), z.string().regex(/^\d(\.\d{1,2})?$/).refine((s) => Number(s) <= 5, "Tối đa 5")]),
  ),
  users: z.string().trim().max(32),
  refunded: z.string().trim().max(32),
}).transform((v): { [k: string]: Json } | null => {
  const out: { [k: string]: Json } = {};
  if (v.rating) out.rating = Number(v.rating);
  if (v.users) out.users = v.users;
  if (v.refunded) out.refunded = v.refunded;
  return Object.keys(out).length ? out : null; // all blank = hide the block on the landing page
});

export type SettingParse = { ok: true; value: Json } | { ok: false; error: string };

/** Turns raw form strings into the exact JSON admin_set_setting accepts. */
export function parseSettingValue(key: string, raw: Record<string, string>): SettingParse {
  let r: z.ZodSafeParseResult<Json>;
  if (Object.hasOwn(NUMERIC_SETTINGS, key)) r = integer.safeParse(raw.value);
  else if (key === "withdraw_eta_text") r = eta.safeParse(raw.value);
  else if (key === "landing_stats") r = landing.safeParse({ rating: raw.rating ?? "", users: raw.users ?? "", refunded: raw.refunded ?? "" });
  else return { ok: false, error: "Cấu hình không hợp lệ" };
  return r.success ? { ok: true, value: r.data } : { ok: false, error: r.error.issues[0]?.message ?? "Dữ liệu không hợp lệ" };
}

/** Reads the stored landing_stats defensively (malformed = empty form). */
export function readLandingStats(v: Json | undefined): { rating: string; users: string; refunded: string } {
  const o = typeof v === "object" && v !== null && !Array.isArray(v) ? v : {};
  return {
    rating: typeof o.rating === "number" ? String(o.rating) : "",
    users: typeof o.users === "string" ? o.users : "",
    refunded: typeof o.refunded === "string" ? o.refunded : "",
  };
}
