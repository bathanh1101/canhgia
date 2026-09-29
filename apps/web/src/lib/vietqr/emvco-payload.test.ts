import { describe, expect, it } from "vitest";
import { buildVietQrPayload, crc16ccitt, hasValidCrc, sanitizeAddInfo } from "./emvco-payload";

// Published CRC-16/CCITT-FALSE check value for "123456789" is 0x29B1.
describe("crc16ccitt", () => {
  it("matches the standard check vector", () => {
    expect(crc16ccitt("123456789")).toBe(0x29b1);
  });
});

describe("buildVietQrPayload", () => {
  const payload = buildVietQrPayload({ bin: "970436", account: "1020304050", amount: 150000, addInfo: "CANHGIA 1a2b3c4d" });

  it("emits the EMVCo TLV structure in order", () => {
    expect(payload.startsWith("000201010212")).toBe(true);
    expect(payload).toContain("38" + "54" + "0010A0000007270124000697043601" + "10" + "1020304050" + "0208QRIBFTTA");
    expect(payload).toContain("5303704" + "540" + "6" + "150000" + "5802VN");
    expect(payload).toContain("62" + "20" + "08" + "16" + "CANHGIA 1a2b3c4d");
  });

  it("ends with a valid CRC", () => {
    expect(hasValidCrc(payload)).toBe(true);
    expect(hasValidCrc(payload.replace("150000", "150001"))).toBe(false);
  });

  it.each([
    { bin: "97043", account: "1020304050", amount: 1000, addInfo: "X" },
    { bin: "970436", account: "12 3", amount: 1000, addInfo: "X" },
    { bin: "970436", account: "1020304050", amount: 0, addInfo: "X" },
    { bin: "970436", account: "1020304050", amount: 10.5, addInfo: "X" },
    { bin: "970436", account: "1020304050", amount: 1000, addInfo: "!!!" },
  ])("rejects invalid input %#", (input) => {
    expect(() => buildVietQrPayload(input)).toThrow("invalid_input");
  });
});

describe("sanitizeAddInfo", () => {
  it("strips diacritics/symbols and caps at 25 chars", () => {
    expect(sanitizeAddInfo("Rút tiền Đơn #12")).toBe("Rut tien Don 12");
    expect(sanitizeAddInfo("A".repeat(40))).toHaveLength(25);
  });
});
