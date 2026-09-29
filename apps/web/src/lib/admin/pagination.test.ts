import { describe, expect, it } from "vitest";
import { pageCount, pageWindow, parsePagination, withPage } from "./pagination";

describe("pagination", () => {
  it("parses page and size with fallbacks and clamp", () => {
    expect(parsePagination({})).toEqual({ page: 1, size: 20, from: 0, to: 19 });
    expect(parsePagination({ page: "3", size: "10" })).toMatchObject({ from: 20, to: 29 });
    expect(parsePagination({ page: "-1", size: "abc" })).toMatchObject({ page: 1, size: 20 });
    expect(parsePagination({ page: "1.5" }).page).toBe(1);
    expect(parsePagination({ size: "5000" }).size).toBe(100);
    expect(parsePagination({ page: ["2", "9"] }).page).toBe(2);
  });
  it("computes page count", () => {
    expect(pageCount(0, 20)).toBe(1);
    expect(pageCount(20, 20)).toBe(1);
    expect(pageCount(21, 20)).toBe(2);
    expect(pageCount(NaN, 20)).toBe(1);
  });
  it("builds window with ellipsis", () => {
    expect(pageWindow(1, 1)).toEqual([1]);
    expect(pageWindow(1, 3)).toEqual([1, 2, 3]);
    expect(pageWindow(10, 20)).toEqual([1, null, 9, 10, 11, null, 20]);
    expect(pageWindow(2, 20)).toEqual([1, 2, 3, null, 20]);
  });
  it("keeps filters and drops empty values in page links", () => {
    expect(withPage({ status: "paid", q: "", page: "4" }, 2)).toBe("?status=paid&page=2");
    expect(withPage({ status: "paid" }, 1)).toBe("?status=paid");
    expect(withPage({}, 1)).toBe("?");
  });
});
