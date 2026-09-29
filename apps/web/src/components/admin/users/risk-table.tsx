import Link from "next/link";
import { DataTable } from "@/components/admin-kit/data-table";
import { StatusBadge } from "@/components/admin-kit/status-badge";
import { Badge } from "@/components/ui/badge";
import { RISK_LABEL, riskTone } from "@/components/admin/withdrawals/withdrawal-state";
import { formatDateTime } from "@/lib/format";

export interface RiskRow {
  userId: string; email: string; score: number; level: string; locked: boolean; lockReason: string | null; kycStatus: string | null; updatedAt: string;
}

export function RiskTable({ rows }: { rows: RiskRow[] }) {
  return (
    <DataTable
      rows={rows}
      rowKey={(r) => r.userId}
      emptyTitle="Không có người dùng phù hợp"
      columns={[
        { key: "user", header: "Người dùng", cell: (r) => <Link className="text-primary underline" href={`/admin/users/${r.userId}`}>{r.email || r.userId.slice(0, 8)}</Link> },
        { key: "score", header: "Điểm rủi ro", cell: (r) => r.score },
        { key: "level", header: "Mức", cell: (r) => <Badge tone={riskTone(r.level)}>{RISK_LABEL[r.level as keyof typeof RISK_LABEL] ?? r.level}</Badge> },
        { key: "kyc", header: "KYC", cell: (r) => (r.kycStatus ? <StatusBadge status={r.kycStatus} /> : "-") },
        { key: "lock", header: "Khóa", cell: (r) => (r.locked ? <Badge tone="danger" title={r.lockReason ?? undefined}>Đã khóa</Badge> : "-") },
        { key: "updated", header: "Cập nhật", cell: (r) => formatDateTime(r.updatedAt) },
      ]}
    />
  );
}
