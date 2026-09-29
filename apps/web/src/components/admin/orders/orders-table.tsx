import Link from "next/link";
import { DataTable, type Column } from "@/components/admin-kit/data-table";
import { StatusBadge } from "@/components/admin-kit/status-badge";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { formatDateTime, formatVnd } from "@/lib/format";
import type { Database } from "@/lib/supabase/database.types";
import { AssignUserDialog } from "./assign-user-dialog";
import { atStatusLabel } from "./orders-export-rows";
import { withParam } from "./orders-links";
import type { UserRef } from "./orders-query";

export type OrderRow = Database["public"]["Views"]["admin_orders"]["Row"];
type SP = Record<string, string | string[] | undefined>;

export function OrdersTable({
  rows, users, merchants, searchParams,
}: { rows: OrderRow[]; users: Map<string, UserRef>; merchants: Map<string, string>; searchParams: SP }) {
  const detailHref = (id: string) => withParam(searchParams, "order", id);
  const columns: Column<OrderRow>[] = [
    { key: "time", header: "Thời gian", cell: (o) => formatDateTime(o.order_time) },
    { key: "merchant", header: "Sàn", cell: (o) => merchants.get(o.merchant_id ?? "") ?? o.merchant_id ?? "-" },
    { key: "tx", header: "Mã giao dịch", cell: (o) => <span className="font-mono text-xs">{o.transaction_id}</span> },
    { key: "product", header: "Sản phẩm", className: "max-w-48 truncate", cell: (o) => o.product_name ?? "-" },
    { key: "value", header: "Giá trị", className: "text-right", cell: (o) => formatVnd(o.value_vnd) },
    { key: "commission", header: "Hoa hồng", className: "text-right", cell: (o) => formatVnd(o.commission_vnd) },
    { key: "cashback", header: "Hoàn user", className: "text-right", cell: (o) => formatVnd(o.user_cashback_vnd) },
    { key: "at", header: "Trạng thái AT", cell: (o) => atStatusLabel(o.at_status) },
    { key: "state", header: "Cộng tiền", cell: (o) => <StatusBadge status={o.credit_state} /> },
    {
      key: "user", header: "User",
      cell: (o) => {
        const u = o.user_id ? users.get(o.user_id) : undefined;
        return o.user_id ? (u?.email ?? o.user_id.slice(0, 8)) : <Badge tone="warning">Chưa khớp</Badge>;
      },
    },
    {
      key: "actions", header: "",
      cell: (o) => (
        <div className="flex gap-2">
          <Button asChild variant="outline" size="sm"><Link href={detailHref(o.id ?? "")}>Chi tiết</Link></Button>
          {o.id && <AssignUserDialog orderId={o.id} currentUser={o.user_id ? users.get(o.user_id)?.email ?? "user" : null} />}
        </div>
      ),
    },
  ];
  return (
    <DataTable
      columns={columns} rows={rows} rowKey={(o) => o.id ?? o.transaction_id ?? ""}
      emptyTitle="Không có đơn hàng" emptyDescription="Thử thay đổi bộ lọc."
    />
  );
}
