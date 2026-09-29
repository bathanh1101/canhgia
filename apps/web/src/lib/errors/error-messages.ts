// One error vocabulary (SQL `raise` message = code). Apps map codes to Vietnamese; never invent codes.

export const ERROR_MESSAGES = {
  // user
  forbidden: "Bạn không có quyền thực hiện thao tác này.",
  rate_limited: "Bạn thao tác quá nhanh. Vui lòng thử lại sau ít phút.",
  account_locked: "Tài khoản đang bị khóa. Vui lòng liên hệ hỗ trợ.",
  insufficient_balance: "Số dư khả dụng không đủ.",
  pin_invalid: "Mã PIN không đúng.",
  pin_locked: "Mã PIN đã bị khóa tạm thời do nhập sai nhiều lần.",
  kyc_required: "Bạn cần xác minh danh tính trước khi thực hiện thao tác này.",
  code_invalid: "Mã không hợp lệ hoặc đã hết hạn.",
  code_pending: "Mã đang chờ được xác nhận.",
  hold_active: "Khoản tiền vẫn đang trong thời gian giữ.",
  daily_cap: "Bạn đã đạt hạn mức rút tiền trong ngày.",
  invalid_input: "Dữ liệu không hợp lệ. Vui lòng kiểm tra lại.",
  // admin per-row
  invalid_state: "Trạng thái hiện tại không cho phép thao tác này.",
  not_claimer: "Yêu cầu này đang được quản trị viên khác xử lý.",
  bank_unverified: "Tài khoản ngân hàng chưa được xác minh.",
  requires_second_approver: "Khoản này cần một quản trị viên thứ hai phê duyệt.",
  // edge extra
  unsupported_url: "Liên kết này chưa được hỗ trợ.",
  merchant_unavailable: "Sàn này hiện không khả dụng.",
} as const;

export type ErrorCode = keyof typeof ERROR_MESSAGES;

export const GENERIC_ERROR = "Đã có lỗi xảy ra. Vui lòng thử lại.";

export function isErrorCode(code: unknown): code is ErrorCode {
  return typeof code === "string" && Object.hasOwn(ERROR_MESSAGES, code);
}

/** Accepts a code, an Error/PostgrestError-like ({message}), or anything; falls back to a generic message. */
export function errorMessage(err: unknown): string {
  if (isErrorCode(err)) return ERROR_MESSAGES[err];
  if (typeof err === "object" && err !== null && "message" in err) {
    const msg = String((err as { message: unknown }).message).trim();
    if (isErrorCode(msg)) return ERROR_MESSAGES[msg];
  }
  return GENERIC_ERROR;
}
