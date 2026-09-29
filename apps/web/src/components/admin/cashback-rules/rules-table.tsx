import { Badge } from "@/components/ui/badge";
import { DataTable } from "@/components/admin-kit/data-table";
import { formatBps } from "@/lib/format";
import { RuleEditDialog } from "./rule-edit-dialog";
import { RuleToggle } from "./rule-toggle";
import type { RuleRow } from "./rules-logic";

export function RulesTable({ rows, maxShareBps }: { rows: RuleRow[]; maxShareBps: number }) {
  return (
    <DataTable
      rows={rows} rowKey={(r) => r.key} emptyTitle="Chưa có cấu hình"
      columns={[
        { key: "merchant", header: "Sàn", cell: (r) => (r.categoryKey === null ? <b>{r.merchantName}</b> : "") },
        { key: "cat", header: "Danh mục", cell: (r) => r.categoryKey ?? "Mặc định" },
        { key: "comm", header: "Sàn trả", className: "text-right", cell: (r) => formatBps(r.commissionBps) },
        {
          key: "share", header: "Hoàn user", className: "text-right",
          cell: (r) => (
            <>
              {formatBps(r.shareBps)}
              {r.ownShareBps === null && r.merchantId !== null && <span className="ml-1 text-xs text-text-muted">(kế thừa)</span>}
            </>
          ),
        },
        { key: "keep", header: "App giữ", className: "text-right", cell: (r) => formatBps(10_000 - r.shareBps) },
        { key: "state", header: "Trạng thái", cell: (r) => <Badge tone={r.enabled ? "success" : "neutral"}>{r.enabled ? "Bật" : "Tắt"}</Badge> },
        {
          key: "actions", header: "",
          cell: (r) => (
            <div className="flex gap-2">
              <RuleEditDialog row={r} maxShareBps={maxShareBps} />
              <RuleToggle row={r} />
            </div>
          ),
        },
      ]}
    />
  );
}
