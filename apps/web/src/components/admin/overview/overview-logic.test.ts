import { describe, expect, it } from "vitest";
import {
  deltaPct, evaluateSync, parseUserStats, previousRange, resolveRange, sparklinePoints, vnToday,
} from "./overview-logic";

describe("ranges", () => {
  it("vnToday rolls over at UTC+7", () => {
    expect(vnToday(Date.parse("2026-09-29T18:00:00Z"))).toBe("2026-09-30");
  });
  it("uses valid params", () => {
    expect(resolveRange({ from: "2026-08-01", to: "2026-08-31" }, "2026-09-29")).toEqual({ from: "2026-08-01", to: "2026-08-31" });
  });
  it("falls back to month-to-date on invalid, inverted or huge ranges", () => {
    const mtd = { from: "2026-09-01", to: "2026-09-29" };
    expect(resolveRange({}, "2026-09-29")).toEqual(mtd);
    expect(resolveRange({ from: "2026-09-10", to: "2026-09-01" }, "2026-09-29")).toEqual(mtd);
    expect(resolveRange({ from: "x", to: "y" }, "2026-09-29")).toEqual(mtd);
    expect(resolveRange({ from: "2020-01-01", to: "2026-09-01" }, "2026-09-29")).toEqual(mtd);
  });
  it("previous range has the same length", () => {
    expect(previousRange({ from: "2026-09-01", to: "2026-09-10" })).toEqual({ from: "2026-08-22", to: "2026-08-31" });
  });
});

describe("deltaPct / sparkline", () => {
  it("computes change and handles zero baseline", () => {
    expect(deltaPct(150, 100)).toBe(50);
    expect(deltaPct(50, 100)).toBe(-50);
    expect(deltaPct(10, 0)).toBeNull();
  });
  it("draws points, empty for no data", () => {
    expect(sparklinePoints([])).toBe("");
    expect(sparklinePoints([0, 10], 100, 10)).toBe("0.0,10.0 100.0,0.0");
  });
});

describe("parseUserStats", () => {
  it("accepts the SQL shape", () => {
    expect(parseUserStats({ new_users_month: 3, d30_retention: 0.25, dau: [{ day: "2026-09-01", count: 4 }, { bad: 1 }] }))
      .toEqual({ newUsersMonth: 3, d30Retention: 0.25, dau: [{ day: "2026-09-01", count: 4 }] });
  });
  it("rejects malformed", () => {
    expect(parseUserStats(null)).toBeNull();
    expect(parseUserStats({ new_users_month: "a", d30_retention: 0, dau: [] })).toBeNull();
    expect(parseUserStats({ new_users_month: 1, d30_retention: 0 })).toBeNull();
  });
});

describe("evaluateSync", () => {
  const now = Date.parse("2026-09-29T12:00:00Z");
  it("flags stale tx_recent, errors, and never-run jobs", () => {
    const out = evaluateSync([
      { job: "tx_recent", last_success_at: "2026-09-29T09:00:00Z", last_error: null },
      { job: "tx_older", last_success_at: "2026-09-29T11:00:00Z", last_error: "rate_limited" },
      { job: "catalog", last_success_at: null, last_error: null },
      { job: "datafeeds", last_success_at: "2026-09-29T11:30:00Z", last_error: null },
    ], now);
    expect(out.map((o) => o.level)).toEqual(["bad", "bad", "warn", "ok"]);
  });
  it("fresh tx_recent is ok", () => {
    expect(evaluateSync([{ job: "tx_recent", last_success_at: "2026-09-29T11:00:00Z", last_error: null }], now)[0].level).toBe("ok");
  });
});
