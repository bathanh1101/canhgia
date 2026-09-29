import { describe, expect, it } from "vitest";
import { statusView } from "./status";

describe("statusView", () => {
  it("maps known statuses", () => {
    expect(statusView("pending")).toEqual({ label: "Chờ xử lý", tone: "warning" });
    expect(statusView("paid").tone).toBe("success");
    expect(statusView("rejected").tone).toBe("danger");
  });
  it("falls back to raw text and handles empty", () => {
    expect(statusView("weird")).toEqual({ label: "weird", tone: "neutral" });
    expect(statusView("toString").label).toBe("toString");
    expect(statusView(null).label).toBe("-");
  });
});
