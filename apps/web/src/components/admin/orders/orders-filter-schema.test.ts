import { describe, expect, it } from "vitest";
import { parseOrdersFilter } from "./orders-filter-schema";

describe("parseOrdersFilter", () => {
  it("parses valid params", () => {
    expect(parseOrdersFilter({ merchant: "shopee", status: "credited", from: "2026-09-01", to: "2026-09-30", q: " AB1 ", unmatched: "1" }))
      .toEqual({ merchant: "shopee", state: "credited", from: "2026-09-01", to: "2026-09-30", q: "AB1", unmatched: true });
  });
  it("treats blanks as absent", () => {
    expect(parseOrdersFilter({ merchant: "", status: "", q: "" })).toEqual({ unmatched: false });
  });
  it("drops unknown enum values, bad dates, oversized search and bad merchant", () => {
    const f = parseOrdersFilter({ status: "hacked", from: "2026-13-45", to: "nope", q: "x".repeat(65), merchant: "a;b", unmatched: "yes" });
    expect(f).toEqual({ unmatched: false });
  });
  it("takes the first of repeated params", () => {
    expect(parseOrdersFilter({ status: ["pending", "credited"] }).state).toBe("pending");
  });
});
