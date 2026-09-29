import { describe, expect, it } from "vitest";
import { approvalPhase, needsSecondApprover, resolveMessage } from "./complaint-state";

describe("complaint state", () => {
  it("threshold is strictly above 2.000.000", () => {
    expect([2_000_000, 2_000_001, 2_500_000].map(needsSecondApprover)).toEqual([false, true, true]);
  });
  it("approval phases", () => {
    expect(approvalPhase({ status: "pending", first_approved_by: null }, "a")).toBe("first");
    expect(approvalPhase({ status: "reviewing", first_approved_by: "a" }, "a")).toBe("wait_other");
    expect(approvalPhase({ status: "reviewing", first_approved_by: "a" }, "b")).toBe("second");
    expect(approvalPhase({ status: "approved", first_approved_by: "a" }, "b")).toBe("closed");
  });
  it("messages by RPC result", () => {
    expect(resolveMessage("requires_second_approver", 2500000)).toContain("admin thứ 2");
    expect(resolveMessage("rejected", 0)).toBe("Đã từ chối khiếu nại");
    expect(resolveMessage("approved", 1)).toContain("Đã duyệt");
  });
});
