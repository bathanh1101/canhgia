import { describe, expect, it } from "vitest";
import { formatBps, formatDate, formatDateTime, formatVnd } from "./format";

describe("format", () => {
  it("formats VND with dot grouping", () => {
    expect(formatVnd(1250000)).toBe("1.250.000đ");
    expect(formatVnd(123456789012n)).toBe("123.456.789.012đ");
    expect(formatVnd("50000")).toBe("50.000đ");
    expect(formatVnd(0)).toBe("0đ");
  });
  it("returns dash for missing / invalid", () => {
    expect(formatVnd(null)).toBe("-");
    expect(formatVnd(NaN)).toBe("-");
    expect(formatDate("garbage")).toBe("-");
    expect(formatDateTime(undefined)).toBe("-");
  });
  it("formats bps as percent", () => {
    expect(formatBps(650)).toBe("6,5%");
    expect(formatBps(2000)).toBe("20%");
    expect(formatBps(null)).toBe("-");
  });
  it("uses Asia/Ho_Chi_Minh", () => {
    // 2026-09-29T20:00Z = 03:00 next day in VN (UTC+7)
    expect(formatDate("2026-09-29T20:00:00Z")).toBe("30/09/2026");
    expect(formatDateTime("2026-09-29T20:00:00Z")).toBe("03:00 30/09/2026");
  });
});
