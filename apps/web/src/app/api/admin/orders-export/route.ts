import ExcelJS from "exceljs";
import { NextResponse, type NextRequest } from "next/server";
import { parseOrdersFilter } from "@/components/admin/orders/orders-filter-schema";
import {
  EXPORT_CHUNK, EXPORT_HEADERS, exportFilename, mapOrderRow, MAX_EXPORT_ROWS,
} from "@/components/admin/orders/orders-export-rows";
import { buildOrdersQuery, findUserIdsByEmail, loadUserRefs } from "@/components/admin/orders/orders-query";
import { requireAdmin } from "@/lib/admin/require-admin";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const fail = (status: number, error: string) => NextResponse.json({ error }, { status, headers: { "Cache-Control": "no-store" } });

export async function GET(req: NextRequest) {
  const { supabase } = await requireAdmin();
  const filter = parseOrdersFilter(Object.fromEntries(req.nextUrl.searchParams));

  try {
    const matched = filter.q ? await findUserIdsByEmail(supabase, filter.q) : [];
    const wb = new ExcelJS.Workbook();
    const ws = wb.addWorksheet("Đơn hàng");
    ws.addRow([...EXPORT_HEADERS]).font = { bold: true };
    for (const col of [5, 6, 7]) ws.getColumn(col).numFmt = "#,##0";

    for (let from = 0, total = Infinity; from < total; from += EXPORT_CHUNK) {
      const { data, count, error } = await buildOrdersQuery(supabase, filter, matched).range(from, from + EXPORT_CHUNK - 1);
      if (error) throw new Error(error.message);
      total = count ?? 0;
      if (total > MAX_EXPORT_ROWS) return fail(400, "Quá 50.000 dòng. Vui lòng chọn khoảng thời gian hẹp hơn.");
      const users = await loadUserRefs(supabase, (data ?? []).map((r) => r.user_id));
      for (const o of data ?? []) ws.addRow(mapOrderRow(o, o.user_id ? users.get(o.user_id) : undefined));
      if (!data?.length) break;
    }

    const body = await wb.xlsx.writeBuffer();
    return new NextResponse(body, {
      headers: {
        "Content-Type": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        "Content-Disposition": `attachment; filename="${exportFilename()}"`,
        "Cache-Control": "no-store",
      },
    });
  } catch (e) {
    console.error("orders-export failed", e instanceof Error ? e.message : e);
    return fail(500, "Không xuất được file. Vui lòng thử lại.");
  }
}
