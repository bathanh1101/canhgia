import { z } from "zod";

export const reportIdSchema = z.number().int().positive();
export const noteSchema = z.string().trim().min(5).max(500);
export const amountSchema = z.number().int().positive().max(1_000_000_000);
export const decisionSchema = z.enum(["approved", "rejected"]);

/** admin-at-lookup response, validated where it enters the app (rows are raw AccessTrade conversions). */
export const lookupResponseSchema = z.object({
  rows: z.array(z.record(z.string(), z.unknown())),
  clicks: z.array(z.object({
    id: z.number(), user_id: z.string(), merchant_id: z.string(), source: z.string(), status: z.string(),
    utm_content: z.string().nullable(), created_at: z.string(),
  })),
});
export type LookupResponse = z.infer<typeof lookupResponseSchema>;
