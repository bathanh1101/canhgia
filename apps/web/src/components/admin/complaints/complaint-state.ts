/** Above this a different second admin must repeat the same amount (enforced in SQL). */
export const SECOND_APPROVER_THRESHOLD_VND = 2_000_000;

export const needsSecondApprover = (amount: number) => amount > SECOND_APPROVER_THRESHOLD_VND;

export const isOpenComplaint = (status: string) => status === "pending" || status === "reviewing";

export type ApprovalPhase = "first" | "second" | "wait_other" | "closed";

/**
 * first: no approval yet; second: another admin already approved > 2tr, I must repeat their amount;
 * wait_other: I made the first approval, a different admin has to finish it.
 */
export function approvalPhase(
  r: { status: string; first_approved_by: string | null }, adminId: string,
): ApprovalPhase {
  if (!isOpenComplaint(r.status)) return "closed";
  if (!r.first_approved_by) return "first";
  return r.first_approved_by === adminId ? "wait_other" : "second";
}

/** RPC result text -> toast message. */
export function resolveMessage(result: string | null, amount: number): string {
  if (result === "requires_second_approver") return `Đã ghi nhận duyệt lần 1 (${amount.toLocaleString("vi-VN")}đ). Cần admin thứ 2 nhập lại đúng số tiền để hoàn tất.`;
  return result === "rejected" ? "Đã từ chối khiếu nại" : "Đã duyệt khiếu nại và cộng tiền hoàn";
}

export const COMPLAINT_STATUSES = [
  { value: "pending", label: "Chờ xử lý" },
  { value: "reviewing", label: "Đang xem xét" },
  { value: "approved", label: "Đã duyệt" },
  { value: "rejected", label: "Từ chối" },
];
