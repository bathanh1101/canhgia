import ExcelJS from "exceljs";
import { NextRequest } from "next/server";
import { describe, expect, it, vi } from "vitest";

const state = { count: 2, auth: "ok" as "ok" | "401", auditError: null as { message: string } | null, audit: [] as unknown[] };
const rows = [
  { id: "1", order_time: "2026-09-01T03:00:00Z", merchant_id: "shopee", transaction_id: "T1", product_name: "A", value_vnd: 1000,
    commission_vnd: 100, user_cashback_vnd: 50, at_status: 1, credit_state: "credited", user_id: "u1" },
  { id: "2", order_time: "2026-09-02T03:00:00Z", merchant_id: "shopee", transaction_id: "T2", product_name: "B", value_vnd: 2000,
    commission_vnd: 200, user_cashback_vnd: 0, at_status: 0, credit_state: "pending", user_id: null },
];

function fakeSb() {
  const chain: unknown = new Proxy({}, {
    get: (_t, m: string) => m === "range"
      ? async () => ({ data: state.count > 50_000 ? [] : rows, count: state.count, error: null })
      : m === "then" ? undefined : () => chain,
  });
  // profiles lookup: .select().in() resolves
  const profiles = { select: () => ({ in: async () => ({ data: [{ id: "u1", email: "a@b.c", short_id: 7 }], error: null }) }) };
  return {
    from: (t: string) => (t === "profiles" ? profiles : chain),
    rpc: async (fn: string, args: unknown) => { state.audit.push([fn, args]); return { data: null, error: state.auditError }; },
  };
}

vi.mock("@/lib/admin/require-admin", () => ({
  requireAdminApi: async () => state.auth === "401"
    ? { ok: false, response: Response.json({ error: "unauthorized" }, { status: 401 }) }
    : { ok: true, supabase: fakeSb(), adminId: "a" },
}));

import { GET } from "./route";

describe("orders-export route", () => {
  it("401 JSON (not a redirect) without a session", async () => {
    state.auth = "401";
    const res = await GET(new NextRequest("http://x/api/admin/orders-export"));
    state.auth = "ok";
    expect(res.status).toBe(401);
    expect((await res.json()).error).toBe("unauthorized");
  });
  it("writes an audit row first and refuses to export when the audit fails", async () => {
    state.audit = [];
    await GET(new NextRequest("http://x/api/admin/orders-export?merchant=shopee"));
    expect(state.audit[0]).toEqual(["admin_log_action", { p_action: "export_orders", p_target: expect.objectContaining({ merchant: "shopee" }) }]);
    state.auditError = { message: "boom" };
    const res = await GET(new NextRequest("http://x/api/admin/orders-export"));
    state.auditError = null;
    expect(res.status).toBe(500);
  });
  it("returns an xlsx with header + rows, no-store, PII-free filename", async () => {
    state.count = 2;
    const res = await GET(new NextRequest("http://x/api/admin/orders-export?merchant=shopee"));
    expect(res.status).toBe(200);
    expect(res.headers.get("Cache-Control")).toBe("no-store");
    expect(res.headers.get("Content-Disposition")).toMatch(/^attachment; filename="don-hang-\d{8}\.xlsx"$/);
    const wb = new ExcelJS.Workbook();
    await wb.xlsx.load(Buffer.from(await res.arrayBuffer()) as unknown as ArrayBuffer);
    const ws = wb.worksheets[0];
    expect(ws.rowCount).toBe(3);
    expect(ws.getRow(1).getCell(1).value).toBe("Thời gian");
    expect(ws.getRow(2).getCell(10).value).toBe("a@b.c");
    expect(ws.getRow(3).getCell(5).value).toBe(2000);
  });
  it("400 when the filter matches more than 50k rows", async () => {
    state.count = 50_001;
    const res = await GET(new NextRequest("http://x/api/admin/orders-export"));
    expect(res.status).toBe(400);
    expect((await res.json()).error).toMatch(/50\.000/);
  });
});
