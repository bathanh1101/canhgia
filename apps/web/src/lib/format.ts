const TZ = "Asia/Ho_Chi_Minh";

const vnd = new Intl.NumberFormat("vi-VN");

/** bigint/number VND (no decimals) → "1.250.000đ". Non-finite → "-". */
export function formatVnd(value: number | bigint | string | null | undefined): string {
  if (value === null || value === undefined || value === "") return "-";
  const n = typeof value === "string" ? Number(value) : value;
  if (typeof n === "number" && !Number.isFinite(n)) return "-";
  return `${vnd.format(n)}đ`;
}

/** basis points → "6,5%" (100 bps = 1%). */
export function formatBps(bps: number | null | undefined): string {
  if (bps === null || bps === undefined || !Number.isFinite(bps)) return "-";
  return `${new Intl.NumberFormat("vi-VN", { maximumFractionDigits: 2 }).format(bps / 100)}%`;
}

function parse(input: string | Date | null | undefined): Date | null {
  if (input === null || input === undefined || input === "") return null;
  const d = input instanceof Date ? input : new Date(input);
  return Number.isNaN(d.getTime()) ? null : d;
}

/** "dd/MM/yyyy" in Asia/Ho_Chi_Minh. */
export function formatDate(input: string | Date | null | undefined): string {
  const d = parse(input);
  if (!d) return "-";
  return new Intl.DateTimeFormat("vi-VN", {
    timeZone: TZ, day: "2-digit", month: "2-digit", year: "numeric",
  }).format(d);
}

/** "HH:mm dd/MM/yyyy" in Asia/Ho_Chi_Minh. */
export function formatDateTime(input: string | Date | null | undefined): string {
  const d = parse(input);
  if (!d) return "-";
  const time = new Intl.DateTimeFormat("vi-VN", {
    timeZone: TZ, hour: "2-digit", minute: "2-digit", hour12: false,
  }).format(d);
  return `${time} ${formatDate(d)}`;
}
