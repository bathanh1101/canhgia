import { describe, expect, it } from "vitest";
import { idsSchema, reasonSchema, settingsSchema, transferRefSchema } from "./schemas";

const uuid = "1a2b3c4d-1111-4222-8333-444455556666";

describe("withdrawal schemas", () => {
  it("transfer_ref 6-64 bank-ref chars, trimmed", () => {
    expect(transferRefSchema.safeParse("  FT26100512345  ").data).toBe("FT26100512345");
    expect(transferRefSchema.safeParse("FT12").success).toBe(false);
    expect(transferRefSchema.safeParse("abc def ghi").success).toBe(false);
    expect(transferRefSchema.safeParse("x".repeat(65)).success).toBe(false);
  });
  it("reason 5-500 chars", () => {
    expect(reasonSchema.safeParse("abcd").success).toBe(false);
    expect(reasonSchema.safeParse("Sai tên chủ TK").success).toBe(true);
    expect(reasonSchema.safeParse("x".repeat(501)).success).toBe(false);
  });
  it("ids are uuids, 1..50", () => {
    expect(idsSchema.safeParse([uuid]).success).toBe(true);
    expect(idsSchema.safeParse([]).success).toBe(false);
    expect(idsSchema.safeParse(["nope"]).success).toBe(false);
  });
  it("settings amounts are integers", () => {
    expect(settingsSchema.safeParse({ autoEnabled: false, autoLimit: 1.5, dailyCap: 10 }).success).toBe(false);
    expect(settingsSchema.safeParse({ autoEnabled: true, autoLimit: 500000, dailyCap: 2000000 }).success).toBe(true);
  });
});
