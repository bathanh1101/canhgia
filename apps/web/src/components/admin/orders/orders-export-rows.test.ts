import { describe, expect, it } from "vitest";
import type { Database } from "@/lib/supabase/database.types";
import { atStatusLabel, EXPORT_HEADERS, exportFilename, mapOrderRow, safeCell } from "./orders-export-rows";

type Row = Database["public"]["Views"]["admin_orders"]["Row"];
const row = { order_time: "2026-09-01T03:00:00Z", merchant_id: "shopee", transaction_id: "T1", product_name: "=cmd()",
  value_vnd: 1000, commission_vnd: 100, user_cashback_vnd: 50, at_status: 1, credit_state: "credited" } as Row;

describe("export rows", () => {
  it("maps a row to the header layout", () => {
    const out = mapOrderRow(row, { id: "u", email: "a@b.c", short_id: 7 });
    expect(out).toHaveLength(EXPORT_HEADERS.length);
    expect(out.slice(4, 10)).toEqual([1000, 100, 50, "Đã duyệt", "credited", "a@b.c"]);
    expect(out[10]).toBe(7);
  });
  it("neutralises spreadsheet formulas", () => {
    expect(mapOrderRow(row)[3]).toBe("'=cmd()");
    expect(safeCell("+1")).toBe("'+1");
    expect(safeCell("ok")).toBe("ok");
  });
  it("handles unmatched orders and nulls", () => {
    const out = mapOrderRow({ ...row, at_status: null, user_cashback_vnd: null } as Row);
    expect(out[6]).toBe(0);
    expect(out[7]).toBe("-");
    expect(out[9]).toBe("");
    expect(atStatusLabel(9)).toBe("9");
  });
  it("filename has no PII", () => {
    expect(exportFilename(new Date("2026-09-29T10:00:00Z"))).toBe("don-hang-20260929.xlsx");
  });
});
