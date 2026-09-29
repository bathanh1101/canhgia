import { describe, expect, it } from "vitest";
import type { WithdrawalRow } from "./types";
import { bulkEligible, claimState, isHighRisk, maskAccount, riskLevelFromScore, summarizeResults, transferMemo } from "./withdrawal-state";

const NOW = Date.parse("2026-10-05T10:00:00Z");
const ago = (m: number) => new Date(NOW - m * 60000).toISOString();
const row = (o: Partial<WithdrawalRow> = {}): WithdrawalRow => ({
  id: "1a2b3c4d-0000-0000-0000-000000000000", createdAt: ago(90), userId: "u", email: "u@x", kycName: "A", amount: 100000,
  status: "pending", bankName: "VCB", bankBin: "970436", accountMask: "******4050", bankAccountId: "b",
  bankVerified: true, snapshotRisk: "low", liveRiskScore: 0, liveRiskLevel: "low", flagCount: 0, claimedBy: null,
  claimedByEmail: null, claimedAt: null, paidByEmail: null, paidAt: null, transferRef: null, rejectReason: null, ...o,
});

describe("claimState", () => {
  it("pending is claimable", () => expect(claimState(row(), "me", NOW)).toBe("claimable"));
  it("own processing claim is mine", () =>
    expect(claimState(row({ status: "processing", claimedBy: "me", claimedAt: ago(50) }), "me", NOW)).toBe("mine"));
  it("fresh claim by another admin blocks", () =>
    expect(claimState(row({ status: "processing", claimedBy: "x", claimedAt: ago(29) }), "me", NOW)).toBe("other"));
  it("claim older than 30 minutes can be re-claimed", () =>
    expect(claimState(row({ status: "processing", claimedBy: "x", claimedAt: ago(30) }), "me", NOW)).toBe("claimable"));
  it("paid is closed", () => expect(claimState(row({ status: "paid" }), "me", NOW)).toBe("closed"));
});

describe("bulkEligible / risk", () => {
  it("excludes high risk rows", () => {
    expect(bulkEligible(row({ snapshotRisk: "high" }), "claim", "me", NOW)).toBe(false);
    expect(bulkEligible(row({ liveRiskLevel: "high" }), "claim", "me", NOW)).toBe(false);
    expect(isHighRisk(row())).toBe(false);
  });
  it("pay/reject need own claim; claim needs claimable", () => {
    const mine = row({ status: "processing", claimedBy: "me", claimedAt: ago(1) });
    expect(bulkEligible(mine, "pay", "me", NOW)).toBe(true);
    expect(bulkEligible(mine, "claim", "me", NOW)).toBe(false);
    expect(bulkEligible(row(), "pay", "me", NOW)).toBe(false);
  });
  it("score thresholds", () => {
    expect([29, 30, 59, 60].map(riskLevelFromScore)).toEqual(["low", "medium", "medium", "high"]);
  });
});

describe("misc", () => {
  it("masks account numbers", () => expect(maskAccount("1020304050")).toBe("******4050"));
  it("summarizes per-row results", () =>
    expect(summarizeResults([{ id: "a", ok: true }, { id: "b", ok: false, error: "not_claimer" }])).toEqual({ ok: 1, failed: 1 }));
  it("memo fits 25 chars", () => expect(transferMemo("1a2b3c4d-1111-2222-3333-444455556666")).toBe("CANHGIA 1a2b3c4d"));
});
