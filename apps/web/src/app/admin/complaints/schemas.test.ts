import { describe, expect, it } from "vitest";
import { amountSchema, decisionSchema, lookupResponseSchema, noteSchema } from "./schemas";

describe("complaint schemas", () => {
  it("amount is a positive integer", () => {
    expect(amountSchema.safeParse(100000).success).toBe(true);
    expect(amountSchema.safeParse(0).success).toBe(false);
    expect(amountSchema.safeParse(10.5).success).toBe(false);
  });
  it("note 5-500 chars, decision enum", () => {
    expect(noteSchema.safeParse("abcd").success).toBe(false);
    expect(noteSchema.safeParse("Không tìm thấy đơn trên AT").success).toBe(true);
    expect(decisionSchema.safeParse("approve").success).toBe(false);
  });
  it("lookup response shape", () => {
    expect(lookupResponseSchema.safeParse({ rows: [{ transaction_id: "X" }], clicks: [] }).success).toBe(true);
    expect(lookupResponseSchema.safeParse({ rows: "x" }).success).toBe(false);
  });
});
