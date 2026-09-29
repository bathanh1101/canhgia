import { describe, expect, it } from "vitest";
import { userIdSchema } from "@/app/admin/users/schemas";
import { assignSchema } from "./orders-action-schemas";

// Dev-seed users use non-RFC uuids; the admin actions must still accept them (regression: "Dữ liệu không hợp lệ" on assign).
const SEED_USER = "33333333-3333-3333-3333-333333333333";
const V4 = "0b6f3c1e-8a52-4d0e-9c1f-2a7d5e4b9f10";

describe("uuid inputs of admin actions", () => {
  it("assignSchema accepts seed-style and v4 uuids, rejects junk", () => {
    expect(assignSchema.safeParse({ orderId: V4, userId: SEED_USER }).success).toBe(true);
    expect(assignSchema.safeParse({ orderId: "nope", userId: SEED_USER }).success).toBe(false);
  });
  it("userIdSchema accepts seed-style uuids, rejects junk", () => {
    expect(userIdSchema.safeParse(SEED_USER).success).toBe(true);
    expect(userIdSchema.safeParse("1234").success).toBe(false);
  });
});
