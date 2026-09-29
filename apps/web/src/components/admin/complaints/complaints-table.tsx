import Link from "next/link";
import { DataTable } from "@/components/admin-kit/data-table";
import { StatusBadge } from "@/components/admin-kit/status-badge";
import { Badge } from "@/components/ui/badge";
import { formatDate, formatDateTime, formatVnd } from "@/lib/format";

export interface ComplaintRow {
  id: number; public_code: string; email: string; merchantName: string; order_code: string; order_value_vnd: number;
  purchased_on: string; status: string; created_at: string; first_approved_by: string | null;
}

export function ComplaintsTable({ rows }: { rows: ComplaintRow[] }) {
  return (
    <DataTable
      rows={rows}
      rowKey={(r) => r.id}
      emptyTitle="Không có khiếu nại"
      columns={[
        { key: "code", header: "Mã", cell: (r) => <Link className="text-primary underline" href={`/admin/complaints/${r.id}`}>{r.public_code}</Link> },
        { key: "user", header: "Người dùng", cell: (r) => r.email },
        { key: "m", header: "Sàn", cell: (r) => r.merchantName },
        { key: "o", header: "Mã đơn", cell: (r) => r.order_code },
        { key: "v", header: "Giá trị", cell: (r) => formatVnd(r.order_value_vnd) },
        { key: "p", header: "Ngày mua", cell: (r) => formatDate(r.purchased_on) },
        { key: "s", header: "Trạng thái", cell: (r) => (<><StatusBadge status={r.status} />{r.first_approved_by && r.status === "reviewing" && <Badge tone="warning" className="ml-1">Chờ admin thứ 2</Badge>}</>) },
        { key: "c", header: "Gửi lúc", cell: (r) => formatDateTime(r.created_at) },
      ]}
    />
  );
}
