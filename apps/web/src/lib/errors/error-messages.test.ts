import { describe, expect, it } from "vitest";
import { ERROR_MESSAGES, GENERIC_ERROR, errorMessage, isErrorCode } from "./error-messages";

const VOCAB = [
  "forbidden", "rate_limited", "account_locked", "insufficient_balance", "pin_invalid", "pin_locked",
  "kyc_required", "code_invalid", "code_pending", "hold_active", "daily_cap", "invalid_input",
  "invalid_state", "not_claimer", "bank_unverified", "unsupported_url", "merchant_unavailable",
  "requires_second_approver",
];

describe("errorMessage", () => {
  it("covers the full vocabulary with non-empty Vietnamese text", () => {
    for (const code of VOCAB) {
      expect(isErrorCode(code)).toBe(true);
      expect(ERROR_MESSAGES[code as keyof typeof ERROR_MESSAGES].length).toBeGreaterThan(5);
    }
    expect(Object.keys(ERROR_MESSAGES).sort()).toEqual([...VOCAB].sort());
  });
  it("maps codes and error-like objects", () => {
    expect(errorMessage("pin_locked")).toBe(ERROR_MESSAGES.pin_locked);
    expect(errorMessage({ message: "forbidden" })).toBe(ERROR_MESSAGES.forbidden);
    expect(errorMessage(new Error(" invalid_state "))).toBe(ERROR_MESSAGES.invalid_state);
  });
  it("falls back for unknown input and prototype keys", () => {
    expect(errorMessage("boom")).toBe(GENERIC_ERROR);
    expect(errorMessage("toString")).toBe(GENERIC_ERROR);
    expect(errorMessage(null)).toBe(GENERIC_ERROR);
    expect(errorMessage({ message: "constructor" })).toBe(GENERIC_ERROR);
  });
});
