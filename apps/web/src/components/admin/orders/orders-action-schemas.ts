import { z } from "zod";

// z.guid(), not z.uuid(): zod 4 uuid() enforces RFC version/variant bits, which rejects valid Postgres uuids such as the dev-seed users (33333333-3333-3333-...). The DB uuid type is the real check.
export const assignSchema = z.object({ orderId: z.guid(), userId: z.guid() });

/** short_id search is numeric; otherwise email fragment. */
export const userSearchSchema = z.string().trim().min(2).max(64);

export const atLookupSchema = z.object({
  merchant_id: z.string().regex(/^[a-z0-9_-]{1,64}$/i),
  order_code: z.string().trim().min(1).max(100),
  purchased_on: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
});

/** Edge response guard: only trust the two documented arrays. */
export const atLookupResultSchema = z.object({
  rows: z.array(z.record(z.string(), z.unknown())),
  clicks: z.array(z.object({
    id: z.union([z.number(), z.string()]), user_id: z.string().nullable(), merchant_id: z.string().nullable().optional(),
    source: z.string().nullable().optional(), status: z.string().nullable().optional(),
    utm_content: z.string().nullable().optional(), created_at: z.string().nullable().optional(),
  })),
});
export type AtLookupResult = z.infer<typeof atLookupResultSchema>;
