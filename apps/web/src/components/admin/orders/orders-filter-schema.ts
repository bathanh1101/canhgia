import { z } from "zod";

export const CREDIT_STATES = ["none", "pending", "credited", "cancelled", "reversed"] as const;

const date = z.string().regex(/^\d{4}-\d{2}-\d{2}$/).refine((s) => !Number.isNaN(Date.parse(`${s}T00:00:00Z`)));
// Blank form fields arrive as "" → treated as absent; anything else invalid is dropped (never throws).
const opt = <T extends z.ZodType>(s: T) => z.preprocess((v) => (v === "" ? undefined : v), s.optional().catch(undefined));

const schema = z.object({
  merchant: opt(z.string().regex(/^[a-z0-9_-]{1,64}$/i)),
  status: opt(z.enum(CREDIT_STATES)),
  from: opt(date),
  to: opt(date),
  q: opt(z.string().trim().max(64)),
  unmatched: opt(z.literal("1")),
});

export interface OrdersFilter {
  merchant?: string;
  state?: (typeof CREDIT_STATES)[number];
  from?: string;
  to?: string;
  q?: string;
  unmatched: boolean;
}

type SP = Record<string, string | string[] | undefined>;

/** Parses URL searchParams. Unknown enum values / malformed dates are ignored rather than trusted. */
export function parseOrdersFilter(sp: SP): OrdersFilter {
  const flat: Record<string, string | undefined> = {};
  for (const k of Object.keys(schema.shape)) flat[k] = Array.isArray(sp[k]) ? sp[k][0] : sp[k];
  const p = schema.parse(flat);
  return {
    merchant: p.merchant, state: p.status, from: p.from, to: p.to,
    q: p.q || undefined, unmatched: p.unmatched === "1",
  };
}
