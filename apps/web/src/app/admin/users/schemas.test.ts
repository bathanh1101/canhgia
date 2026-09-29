import { describe, expect, it } from "vitest";
import { adjustAmountSchema, flagStatusSchema, kycDecisionSchema, reasonSchema } from "./schemas";

describe("users schemas", () => {
  it("adjustment: non-zero integer within 1 tỷ", () => {
    expect(adjustAmountSchema.safeParse(-50000).success).toBe(true);
    expect(adjustAmountSchema.safeParse(0).success).toBe(false);
    expect(adjustAmountSchema.safeParse(1.5).success).toBe(false);
    expect(adjustAmountSchema.safeParse(2_000_000_000).success).toBe(false);
  });
  it("reason 5-500 chars", () => {
    expect(reasonSchema.safeParse("ngắn").success).toBe(false);
    expect(reasonSchema.safeParse("Gian lận nhiều tài khoản").success).toBe(true);
  });
  it("enums", () => {
    expect(flagStatusSchema.safeParse("open").success).toBe(false);
    expect(kycDecisionSchema.safeParse("verified").success).toBe(true);
  });
});
