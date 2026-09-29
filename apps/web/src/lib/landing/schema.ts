import { z } from "zod";

// landing_stats (admin-editable jsonb, object | null). Every field is optional; an absent field hides its stat.
export const landingStatsSchema = z
  .object({
    rating: z.number().min(0).max(5).optional(), // e.g. 4.8
    users: z.string().trim().min(1).max(24).optional(), // e.g. "500K+"
    refunded: z.string().trim().min(1).max(24).optional(), // e.g. "12 tỷ đ"
  })
  .nullable();

export const publicSettingsSchema = z.object({
  min_withdraw_vnd: z.coerce.number().int().positive().nullish(),
  landing_stats: landingStatsSchema.catch(null),
  max_rate_bps: z.number().int().nonnegative().catch(0),
  active_merchants: z.number().int().nonnegative().catch(0),
});

export const merchantRateSchema = z.object({
  merchant_id: z.string(),
  name: z.string(),
  badge_letter: z.string().max(3),
  max_user_rate_bps: z.number().int().nonnegative(),
});

export type LandingStats = z.infer<typeof landingStatsSchema>;
export type PublicSettings = z.infer<typeof publicSettingsSchema>;
export type MerchantRate = z.infer<typeof merchantRateSchema>;

export interface LandingLinks {
  play?: string;
  appstore?: string;
  cws?: string;
}

export interface LandingData {
  settings: PublicSettings | null;
  merchants: MerchantRate[];
  links: LandingLinks;
}
