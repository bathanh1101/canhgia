import { z } from "zod";

export const userIdSchema = z.uuid();
export const reasonSchema = z.string().trim().min(5).max(500);
/** Wallet adjustment in VND: non-zero integer, either sign (negative = deduct). */
export const adjustAmountSchema = z.number().int().refine((n) => n !== 0).refine((n) => Math.abs(n) <= 1_000_000_000);
export const flagStatusSchema = z.enum(["dismissed", "actioned"]);
export const kycDecisionSchema = z.enum(["verified", "rejected"]);
