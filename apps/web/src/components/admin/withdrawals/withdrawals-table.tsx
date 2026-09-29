"use client";

import { useMemo, useState, useTransition } from "react";
import { EmptyState } from "@/components/admin-kit/states";
import { notifyResult } from "@/components/admin-kit/notify-result";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Checkbox } from "@/components/ui/checkbox";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { claimWithdrawal } from "@/app/admin/withdrawals/actions";
import { formatDateTime, formatVnd } from "@/lib/format";
import { BulkActionBar } from "./bulk-action-bar";
import { RiskBadge } from "./risk-badge";
import { TransferDialog } from "./transfer-dialog";
import type { WithdrawalRow } from "./types";
import { RECLAIM_AFTER_MIN, bulkEligible, claimState, isHighRisk, minutesSince } from "./withdrawal-state";

export function WithdrawalsTable({ rows, adminId }: { rows: WithdrawalRow[]; adminId: string }) {
  const [now] = useState(() => Date.now()); // fixed per mount; the page is re-fetched on every action
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [activeId, setActiveId] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const active = rows.find((r) => r.id === activeId) ?? null;
  const labels = useMemo(() => new Map(rows.map((r) => [r.id, `${r.email} · ${formatVnd(r.amount)}`])), [rows]);
  const picked = rows.filter((r) => selected.has(r.id));
  const claimIds = picked.filter((r) => bulkEligible(r, "claim", adminId, now)).map((r) => r.id);
  const ownedIds = picked.filter((r) => bulkEligible(r, "pay", adminId, now)).map((r) => r.id);

  const open = (row: WithdrawalRow) => {
    if (claimState(row, adminId, now) === "mine") return setActiveId(row.id);
    start(async () => {
      try {
        const r = await claimWithdrawal(row.id);
        if (r.ok) setActiveId(row.id);
        else notifyResult({ ok: false, error: "Admin khác đang xử lý yêu cầu này (hoặc yêu cầu đã đổi trạng thái)." });
      } catch {
        notifyResult({ ok: false, error: "Đã có lỗi xảy ra. Vui lòng thử lại." });
      }
    });
  };
  const toggle = (id: string, on: boolean) =>
    setSelected((s) => { const n = new Set(s); if (on) n.add(id); else n.delete(id); return n; });

  if (rows.length === 0) return <Card><EmptyState title="Không có yêu cầu rút tiền nào đang chờ" /></Card>;
  return (
    <>
      {selected.size > 0 && <BulkActionBar claimIds={claimIds} ownedIds={ownedIds} labels={labels} />}
      <Card className="overflow-x-auto">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead className="w-10" />
              <TableHead>Thời gian</TableHead><TableHead>Người dùng</TableHead><TableHead>Số tiền</TableHead>
              <TableHead>Ngân hàng</TableHead><TableHead>Rủi ro</TableHead><TableHead>Xử lý</TableHead><TableHead />
            </TableRow>
          </TableHeader>
          <TableBody>
            {rows.map((r) => {
              const state = claimState(r, adminId, now);
              const high = isHighRisk(r);
              return (
                <TableRow key={r.id}>
                  <TableCell>
                    <Checkbox aria-label={`Chọn ${r.email}`} disabled={high} title={high ? "Rủi ro cao: xử lý từng dòng, không thao tác hàng loạt" : undefined}
                      checked={selected.has(r.id)} onCheckedChange={(c) => toggle(r.id, c === true)} />
                  </TableCell>
                  <TableCell>{formatDateTime(r.createdAt)}</TableCell>
                  <TableCell><div>{r.email}</div><div className="text-xs text-text-muted">{r.kycName ?? "Chưa KYC"}</div></TableCell>
                  <TableCell className="font-semibold">{formatVnd(r.amount)}</TableCell>
                  <TableCell>
                    <div>{r.bankName} · {r.accountMask}</div>
                    {!r.bankVerified && <Badge tone="warning">Chưa xác minh tên</Badge>}
                  </TableCell>
                  <TableCell>
                    <RiskBadge snapshot={r.snapshotRisk} live={r.liveRiskLevel} score={r.liveRiskScore} />
                    {r.flagCount > 0 && <Badge tone="danger" className="mt-1">{r.flagCount} cảnh báo</Badge>}
                  </TableCell>
                  <TableCell>
                    {r.status === "processing" && (
                      <Badge tone="info">Đang xử lý bởi {state === "mine" ? "bạn" : r.claimedByEmail ?? "admin khác"} · {minutesSince(r.claimedAt, now)} phút</Badge>
                    )}
                    {state === "other" && <div className="mt-1 text-xs text-text-muted">Nhận lại được sau {RECLAIM_AFTER_MIN} phút</div>}
                  </TableCell>
                  <TableCell>
                    <Button size="sm" disabled={pending || state === "other"} onClick={() => open(r)}>
                      {state === "mine" ? "Tiếp tục" : "Chuyển khoản"}
                    </Button>
                  </TableCell>
                </TableRow>
              );
            })}
          </TableBody>
        </Table>
      </Card>
      {active && <TransferDialog row={active} onClose={() => setActiveId(null)} />}
    </>
  );
}
