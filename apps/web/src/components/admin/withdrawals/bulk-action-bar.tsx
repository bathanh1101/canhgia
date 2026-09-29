"use client";

import { useState, useTransition } from "react";
import { notifyResult } from "@/components/admin-kit/notify-result";
import { Button } from "@/components/ui/button";
import { claimWithdrawals, rejectWithdrawals } from "@/app/admin/withdrawals/actions";
import { reasonSchema } from "@/app/admin/withdrawals/schemas";
import type { ActionResult } from "@/lib/admin/action-result";
import { errorMessage } from "@/lib/errors/error-messages";
import { ReasonDialog } from "./reason-dialog";
import type { RowResult } from "./types";

/** Per-row outcome list: ok, or the Vietnamese meaning of not_claimer / bank_unverified / invalid_state. */
export function ResultsList({ results, labels }: { results: RowResult[]; labels: Map<string, string> }) {
  if (results.length === 0) return null;
  return (
    <ul className="mt-3 flex flex-col gap-1 text-sm" aria-label="Kết quả từng dòng">
      {results.map((r) => (
        <li key={r.id} className={r.ok ? "text-primary" : "text-danger"}>
          {labels.get(r.id) ?? r.id}: {r.ok ? "Thành công" : errorMessage(r.error)}
        </li>
      ))}
    </ul>
  );
}

/** Bulk claim/reject only: paying needs one bank transfer reference per row, so it lives in the per-row dialog. */
export function BulkActionBar({
  claimIds, ownedIds, labels,
}: { claimIds: string[]; ownedIds: string[]; labels: Map<string, string> }) {
  const [results, setResults] = useState<RowResult[]>([]);
  const [pending, start] = useTransition();

  const run = async (fn: () => Promise<ActionResult<RowResult[]>>): Promise<ActionResult<RowResult[]>> => {
    const r = await fn();
    if (r.ok) setResults(r.data ?? []);
    return r;
  };
  const claim = () =>
    start(async () => {
      try { notifyResult(await run(() => claimWithdrawals(claimIds))); }
      catch { notifyResult({ ok: false, error: "Đã có lỗi xảy ra. Vui lòng thử lại." }); }
    });

  return (
    <div className="mb-4 rounded-2xl border border-border bg-surface p-3">
      <div className="flex flex-wrap items-center gap-2">
        <span className="text-sm text-text-2">Đã chọn {claimIds.length + ownedIds.length}</span>
        <Button size="sm" disabled={pending || claimIds.length === 0} onClick={claim}>Nhận xử lý ({claimIds.length})</Button>
        <ReasonDialog
          trigger={<Button size="sm" variant="destructive" disabled={pending || ownedIds.length === 0}>Từ chối ({ownedIds.length})</Button>}
          title="Từ chối các yêu cầu đã chọn" description="Số tiền được hoàn lại vào ví từng người dùng." label="Lý do (5-500 ký tự)"
          schema={reasonSchema} destructive confirmLabel="Từ chối"
          onSubmit={(reason) => run(() => rejectWithdrawals(ownedIds, reason))}
        />
      </div>
      <ResultsList results={results} labels={labels} />
    </div>
  );
}
