import { DataTable } from "@/components/admin-kit/data-table";
import { StatusBadge } from "@/components/admin-kit/status-badge";
import { formatDateTime, formatVnd } from "@/lib/format";
import type { WithdrawalRow } from "./types";

export function WithdrawalHistoryTable({ rows }: { rows: WithdrawalRow[] }) {
  return (
    <DataTable
      rows={rows}
      rowKey={(r) => r.id}
      emptyTitle="Chưa có lịch sử"
      columns={[
        { key: "time", header: "Thời gian", cell: (r) => formatDateTime(r.paidAt ?? r.createdAt) },
        { key: "user", header: "Người dùng", cell: (r) => r.email },
        { key: "amount", header: "Số tiền", cell: (r) => formatVnd(r.amount) },
        { key: "bank", header: "Ngân hàng", cell: (r) => `${r.bankName} · ${r.accountMask}` },
        { key: "status", header: "Trạng thái", cell: (r) => <StatusBadge status={r.status} /> },
        { key: "claimer", header: "Người nhận xử lý", cell: (r) => r.claimedByEmail ?? "-" },
        { key: "payer", header: "Người chuyển", cell: (r) => r.paidByEmail ?? "-" },
        { key: "ref", header: "Mã GD / lý do", cell: (r) => r.transferRef ?? r.rejectReason ?? "-" },
      ]}
    />
  );
}
