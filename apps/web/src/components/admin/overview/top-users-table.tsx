import { DataTable } from "@/components/admin-kit/data-table";
import { formatVnd } from "@/lib/format";

export interface TopUser { user_id: string; email: string; gmv_vnd: number; cashback_vnd: number; orders: number }

export function TopUsersTable({ rows }: { rows: TopUser[] }) {
  return (
    <DataTable
      rows={rows} rowKey={(r) => r.user_id} emptyTitle="Chưa có người dùng có đơn"
      columns={[
        { key: "email", header: "Email", cell: (r) => r.email },
        { key: "orders", header: "Số đơn", className: "text-right", cell: (r) => r.orders },
        { key: "gmv", header: "GMV", className: "text-right", cell: (r) => formatVnd(r.gmv_vnd) },
        { key: "cb", header: "Đã hoàn", className: "text-right", cell: (r) => formatVnd(r.cashback_vnd) },
      ]}
    />
  );
}
