/** CRC-16/CCITT-FALSE (poly 0x1021, init 0xFFFF) as required by EMVCo tag 63. */
export function crc16ccitt(input: string): number {
  let crc = 0xffff;
  for (let i = 0; i < input.length; i++) {
    crc ^= input.charCodeAt(i) << 8;
    for (let b = 0; b < 8; b++) crc = crc & 0x8000 ? ((crc << 1) ^ 0x1021) & 0xffff : (crc << 1) & 0xffff;
  }
  return crc;
}

const tlv = (id: string, value: string) => id + value.length.toString().padStart(2, "0") + value;

export interface VietQrInput {
  /** NAPAS bank BIN, 6 digits. */
  bin: string;
  account: string;
  /** VND, positive integer. */
  amount: number;
  /** Transfer memo (tag 62/08), max 25 chars. */
  addInfo: string;
}

const MAX_ADD_INFO = 25;

/** Strips diacritics and anything outside [A-Za-z0-9 ] so every bank app accepts the memo. */
export function sanitizeAddInfo(text: string): string {
  return text
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .replace(/đ/g, "d")
    .replace(/Đ/g, "D")
    .replace(/[^A-Za-z0-9 ]/g, "")
    .trim()
    .slice(0, MAX_ADD_INFO);
}

/** Builds the NAPAS 247 (VietQR) EMVCo payload. Throws on invalid input: a wrong QR moves real money. */
export function buildVietQrPayload(p: VietQrInput): string {
  if (!/^\d{6}$/.test(p.bin)) throw new Error("invalid_input");
  if (!/^[0-9A-Za-z]{4,19}$/.test(p.account)) throw new Error("invalid_input");
  if (!Number.isSafeInteger(p.amount) || p.amount <= 0) throw new Error("invalid_input");
  const addInfo = sanitizeAddInfo(p.addInfo);
  if (!addInfo) throw new Error("invalid_input");

  const merchant = tlv("00", "A000000727") + tlv("01", tlv("00", p.bin) + tlv("01", p.account)) + tlv("02", "QRIBFTTA");
  const body =
    tlv("00", "01") + tlv("01", "12") + tlv("38", merchant) + tlv("53", "704") + tlv("54", String(p.amount)) +
    tlv("58", "VN") + tlv("62", tlv("08", addInfo)) + "6304";
  return body + crc16ccitt(body).toString(16).toUpperCase().padStart(4, "0");
}

/** True when the trailing tag-63 CRC matches the rest of the payload. */
export function hasValidCrc(payload: string): boolean {
  if (payload.length < 8 || payload.slice(-8, -4) !== "6304") return false;
  return crc16ccitt(payload.slice(0, -4)).toString(16).toUpperCase().padStart(4, "0") === payload.slice(-4);
}
