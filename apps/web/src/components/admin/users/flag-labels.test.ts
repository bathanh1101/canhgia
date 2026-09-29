import { describe, expect, it } from "vitest";
import { evidenceEntries, flagLabel, isUserKey } from "./flag-labels";

describe("flag helpers", () => {
  it("labels every fraud type, falls back to the raw type", () => {
    expect(flagLabel("shared_identity")).toBe("Trùng CCCD");
    expect(flagLabel("negative_balance_risk")).toBe("Nguy cơ âm ví");
    expect(flagLabel("brand_new")).toBe("brand_new");
  });
  it("flattens evidence objects and tolerates junk", () => {
    expect(evidenceEntries({ bank_bin: "970436", user_ids: ["a", "b"], n: 3, o: { x: 1 } })).toEqual([
      { key: "bank_bin", values: ["970436"] },
      { key: "user_ids", values: ["a", "b"] },
      { key: "n", values: ["3"] },
      { key: "o", values: ['{"x":1}'] },
    ]);
    expect(evidenceEntries(null)).toEqual([]);
    expect(evidenceEntries([1])).toEqual([]);
  });
  it("detects user-reference keys", () => {
    expect(["user_id", "user_ids", "referrer_id", "order_id"].map(isUserKey)).toEqual([true, true, true, false]);
  });
});
