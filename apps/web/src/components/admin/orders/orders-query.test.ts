import type { SupabaseClient } from "@supabase/supabase-js";
import { describe, expect, it } from "vitest";
import type { Database } from "@/lib/supabase/database.types";
import { buildOrdersQuery, escapeLike, findUserIdsByEmail, nextDay } from "./orders-query";

/** Chainable fake recording every call as [method, ...args]. */
function fakeSb() {
  const calls: unknown[][] = [];
  const chain: unknown = new Proxy({}, {
    get: (_t, m: string) => (...a: unknown[]) => { calls.push([m, ...a]); return chain; },
  });
  const sb = { from: (t: string) => { calls.push(["from", t]); return chain; } } as unknown as SupabaseClient<Database>;
  return { sb, calls };
}
const has = (calls: unknown[][], ...c: unknown[]) => calls.some((x) => JSON.stringify(x) === JSON.stringify(c));

describe("escapeLike / nextDay", () => {
  it("escapes wildcards and strips or() syntax chars", () => {
    expect(escapeLike("a%b_c,d(e)")).toBe("a\\%b\\_cde");
  });
  it("rolls over month and year", () => {
    expect(nextDay("2026-09-30")).toBe("2026-10-01");
    expect(nextDay("2026-12-31")).toBe("2027-01-01");
  });
});

describe("buildOrdersQuery", () => {
  it("reads the admin view with no filters", () => {
    const { sb, calls } = fakeSb();
    buildOrdersQuery(sb, { unmatched: false });
    expect(calls[0]).toEqual(["from", "admin_orders"]);
    expect(calls.some((c) => ["eq", "is", "gte", "lt", "or"].includes(c[0] as string))).toBe(false);
  });
  it("applies every filter, VN-timezone date bounds and exclusive end", () => {
    const { sb, calls } = fakeSb();
    buildOrdersQuery(sb, { merchant: "shopee", state: "credited", from: "2026-09-01", to: "2026-09-30", unmatched: true, q: "A_1" });
    expect(has(calls, "eq", "merchant_id", "shopee")).toBe(true);
    expect(has(calls, "eq", "credit_state", "credited")).toBe(true);
    expect(has(calls, "is", "user_id", null)).toBe(true);
    expect(has(calls, "gte", "order_time", "2026-09-01T00:00:00+07:00")).toBe(true);
    expect(has(calls, "lt", "order_time", "2026-10-01T00:00:00+07:00")).toBe(true);
    expect(has(calls, "or", "transaction_id.ilike.%A\\_1%")).toBe(true);
  });
  it("adds matched user ids to the search", () => {
    const { sb, calls } = fakeSb();
    buildOrdersQuery(sb, { unmatched: false, q: "lan@" }, ["11111111-1111-1111-1111-111111111111"]);
    expect(has(calls, "or", "transaction_id.ilike.%lan@%,user_id.in.(11111111-1111-1111-1111-111111111111)")).toBe(true);
  });
});

describe("findUserIdsByEmail", () => {
  it("skips short non-email terms without querying", async () => {
    const { sb, calls } = fakeSb();
    expect(await findUserIdsByEmail(sb, "ab")).toEqual([]);
    expect(calls).toHaveLength(0);
  });
});
