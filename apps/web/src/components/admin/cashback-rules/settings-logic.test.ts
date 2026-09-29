import { describe, expect, it } from "vitest";
import { parseSettingValue, readLandingStats } from "./settings-logic";

describe("parseSettingValue", () => {
  it("numeric settings become numbers", () => {
    expect(parseSettingValue("min_withdraw_vnd", { value: " 50000 " })).toEqual({ ok: true, value: 50000 });
  });
  it("rejects negative, decimal or huge numbers", () => {
    for (const v of ["-1", "1.5", "", "1234567890123"]) expect(parseSettingValue("click_limit_per_hour", { value: v }).ok).toBe(false);
  });
  it("eta text is trimmed and length-checked", () => {
    expect(parseSettingValue("withdraw_eta_text", { value: " 1-2 ngày " })).toEqual({ ok: true, value: "1-2 ngày" });
    expect(parseSettingValue("withdraw_eta_text", { value: "" }).ok).toBe(false);
    expect(parseSettingValue("withdraw_eta_text", { value: "x".repeat(101) }).ok).toBe(false);
  });
  it("landing_stats writes the documented shape", () => {
    expect(parseSettingValue("landing_stats", { rating: "4,8", users: "10.000+", refunded: "" }))
      .toEqual({ ok: true, value: { rating: 4.8, users: "10.000+" } });
  });
  it("landing_stats all blank = null; rating >5 rejected", () => {
    expect(parseSettingValue("landing_stats", { rating: "", users: "", refunded: "" })).toEqual({ ok: true, value: null });
    expect(parseSettingValue("landing_stats", { rating: "5.5", users: "", refunded: "" }).ok).toBe(false);
  });
  it("unknown key rejected (never forwarded to SQL)", () => {
    expect(parseSettingValue("auto_payout_enabled", { value: "true" }).ok).toBe(false);
  });
});

describe("readLandingStats", () => {
  it("reads stored value and tolerates junk", () => {
    expect(readLandingStats({ rating: 4.5, users: "1k" })).toEqual({ rating: "4.5", users: "1k", refunded: "" });
    expect(readLandingStats(null)).toEqual({ rating: "", users: "", refunded: "" });
    expect(readLandingStats([1] as never)).toEqual({ rating: "", users: "", refunded: "" });
  });
});
