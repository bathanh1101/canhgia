import { describe, expect, it } from "vitest";
import {
  bpsToPercent, buildRuleRows, effectiveShare, maxShareBps, percentToBps, ruleFormSchema, simulatorSchema, tierFormSchema,
} from "./rules-logic";

describe("bps <-> percent", () => {
  it("converts both ways", () => {
    expect(bpsToPercent(1250)).toBe("12,5");
    expect(bpsToPercent(5000)).toBe("50");
    expect(percentToBps("12,5")).toBe(1250);
    expect(percentToBps("0.07")).toBe(7);
    expect(percentToBps(100)).toBe(10_000);
  });
  it("rejects out of range, too precise, or junk", () => {
    for (const bad of ["100.01", "-1", "1.234", "abc", "", "1e2"]) expect(percentToBps(bad)).toBeNull();
  });
  it("max share leaves room for VIP", () => {
    expect(maxShareBps([{ bonus_bps: 0 }, { bonus_bps: 2000 }])).toBe(8000);
    expect(maxShareBps([])).toBe(10_000);
  });
});

describe("form schemas", () => {
  it("rule form converts percent to bps", () => {
    const r = ruleFormSchema.parse({ merchantId: "shopee", categoryKey: null, sharePercent: "60", enabled: true });
    expect(r.sharePercent).toBe(6000);
    expect(r.note).toBe("");
  });
  it("rule form rejects bad percent", () => {
    expect(ruleFormSchema.safeParse({ merchantId: null, categoryKey: null, sharePercent: "120", enabled: true }).success).toBe(false);
  });
  it("tier form / simulator validate numbers", () => {
    expect(tierFormSchema.parse({ code: "silver", bonusPercent: "5", minGmv: "1000000" })).toEqual({ code: "silver", bonusPercent: 500, minGmv: 1_000_000 });
    expect(tierFormSchema.safeParse({ code: "silver", bonusPercent: "5", minGmv: "-1" }).success).toBe(false);
    expect(simulatorSchema.safeParse({ merchantId: "shopee", categoryKey: "", orderValue: "0", tierCode: "none" }).success).toBe(false);
    expect(simulatorSchema.parse({ merchantId: "shopee", categoryKey: "", orderValue: "500000", tierCode: "none" }).orderValue).toBe(500_000);
  });
});

describe("effectiveShare precedence", () => {
  const rules = [
    { merchant_id: null, category_key: null, user_share_bps: 5000 },
    { merchant_id: null, category_key: "fashion", user_share_bps: 4000 },
    { merchant_id: "shopee", category_key: null, user_share_bps: 6000 },
    { merchant_id: "shopee", category_key: "phone", user_share_bps: 0 },
  ];
  it("picks most specific, merchant before category", () => {
    expect(effectiveShare(rules, "shopee", "phone")).toBe(0);
    expect(effectiveShare(rules, "shopee", "fashion")).toBe(6000);
    expect(effectiveShare(rules, "lazada", "fashion")).toBe(4000);
    expect(effectiveShare(rules, "lazada", null)).toBe(5000);
    expect(effectiveShare([], "x", null)).toBe(0);
  });
  it("skipOwn gives the inherited value", () => {
    expect(effectiveShare(rules, "shopee", "phone", true)).toBe(6000);
  });
});

describe("buildRuleRows", () => {
  const rows = buildRuleRows(
    [{ id: "shopee", name: "Shopee" }, { id: "lazada", name: "Lazada" }],
    [{ merchant_id: "shopee", category_key: "", commission_rate_bps: 500 }, { merchant_id: "shopee", category_key: "phone", commission_rate_bps: 200 }],
    [{ merchant_id: null, category_key: null, user_share_bps: 5000 }, { merchant_id: "shopee", category_key: "phone", user_share_bps: 0 }],
  );
  it("emits default, merchant and category rows", () => {
    expect(rows.map((r) => r.key)).toEqual(["*/*", "shopee/*", "shopee/phone", "lazada/*"]);
  });
  it("computes state per row", () => {
    const phone = rows.find((r) => r.key === "shopee/phone")!;
    expect(phone).toMatchObject({ commissionBps: 200, ownShareBps: 0, shareBps: 0, enabled: false, inheritedBps: 5000 });
    expect(rows.find((r) => r.key === "lazada/*")).toMatchObject({ commissionBps: null, ownShareBps: null, shareBps: 5000, enabled: true });
  });
});
