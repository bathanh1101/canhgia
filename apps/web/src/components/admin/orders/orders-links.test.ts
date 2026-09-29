import { expect, it } from "vitest";
import { withParam } from "./orders-links";

it("adds, replaces and removes a param keeping others", () => {
  expect(withParam({ merchant: "shopee", page: "2" }, "order", "x")).toBe("?merchant=shopee&page=2&order=x");
  expect(withParam({ order: "old", q: "a" }, "order", "new")).toBe("?q=a&order=new");
  expect(withParam({ order: "old" }, "order", null)).toBe("?");
});
