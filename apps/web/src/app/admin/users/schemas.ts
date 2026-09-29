import { z } from "zod";

// z.guid(), not z.uuid(): zod 4 uuid() enforces RFC version/variant bits, which rejects valid Postgres uuids such as the dev-seed users (33333333-3333-3333-...). The DB uuid type is the real check.
export const userIdSchema = z.guid();
export const reasonSchema = z.string().trim().min(5).max(500);
/** Wallet adjustment in VND: non-zero integer, either sign (negative = deduct). */
export const adjustAmountSchema = z.number().int().refine((n) => n !== 0).refine((n) => Math.abs(n) <= 1_000_000_000);
export const flagStatusSchema = z.enum(["dismissed", "actioned"]);
export const kycDecisionSchema = z.enum(["verified", "rejected"]);
