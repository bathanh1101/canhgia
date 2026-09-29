import type { Database } from "@/lib/supabase/database.types";
import type { UserRef } from "./orders-query";

type OrderRow = Database["public"]["Views"]["admin_orders"]["Row"];

export const MAX_EXPORT_ROWS = 50_000;
export const EXPORT_CHUNK = 1000;

export const EXPORT_HEADERS = [
  "Thời gian", "Sàn", "Mã giao dịch", "Sản phẩm", "Giá trị (VND)", "Hoa hồng (VND)",
  "Hoàn user (VND)", "Trạng thái AT", "Trạng thái cộng tiền", "Email user", "Mã user",
] as const;

const AT_STATUS: Record<number, string> = { 0: "Chờ duyệt", 1: "Đã duyệt", 2: "Bị hủy" };

export function atStatusLabel(s: number | null | undefined): string {
  return s === null || s === undefined ? "-" : (AT_STATUS[s] ?? String(s));
}

/** CSV/Excel formula injection guard: a leading = + - @ would be evaluated by spreadsheets. */
export function safeCell(v: string): string {
  return /^[=+\-@\t\r]/.test(v) ? `'${v}` : v;
}

export function mapOrderRow(o: OrderRow, user?: UserRef): (string | number)[] {
  return [
    o.order_time ?? "", o.merchant_id ?? "", safeCell(o.transaction_id ?? ""), safeCell(o.product_name ?? ""),
    o.value_vnd ?? 0, o.commission_vnd ?? 0, o.user_cashback_vnd ?? 0,
    atStatusLabel(o.at_status), o.credit_state ?? "", safeCell(user?.email ?? ""), user ? user.short_id : "",
  ];
}

export function exportFilename(now = new Date()): string {
  return `don-hang-${now.toISOString().slice(0, 10).replaceAll("-", "")}.xlsx`;
}
