"use client";

import { useState, useTransition } from "react";
import { notifyResult } from "@/components/admin-kit/notify-result";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { lookupAccessTrade } from "@/app/admin/complaints/actions";
import type { LookupResponse } from "@/app/admin/complaints/schemas";
import { formatDateTime, formatVnd } from "@/lib/format";

const text = (v: unknown) => (v === null || v === undefined ? "-" : String(v));

/** Manual AccessTrade lookup (shares the AT rate bucket, may answer `rate_limited`). */
export function AtLookupPanel({ reportId, reportUserId }: { reportId: number; reportUserId: string }) {
  const [res, setRes] = useState<LookupResponse | null>(null);
  const [pending, start] = useTransition();

  const run = () =>
    start(async () => {
      try {
        const r = await lookupAccessTrade(reportId);
        if (r.ok) setRes(r.data ?? null);
        notifyResult(r);
      } catch {
        notifyResult({ ok: false, error: "Đã có lỗi xảy ra. Vui lòng thử lại." });
      }
    });

  return (
    <Card className="p-4">
      <div className="flex items-center justify-between gap-2">
        <h3 className="font-semibold">Tra cứu AccessTrade</h3>
        <Button size="sm" variant="outline" onClick={run} disabled={pending}>{pending ? "Đang tra cứu..." : "Tra cứu"}</Button>
      </div>
      {res && res.rows.length === 0 && <p className="mt-3 text-sm text-text-muted">AccessTrade chưa ghi nhận đơn có mã này trong ±3 ngày quanh ngày mua.</p>}
      {res && res.rows.length > 0 && (
        <ul className="mt-3 flex flex-col gap-2 text-sm">
          {res.rows.map((row, i) => {
            const click = res.clicks.find((c) => c.utm_content === row.utm_content);
            const mine = click?.user_id === reportUserId;
            return (
              <li key={i} className="rounded-lg border border-primary bg-primary-tint p-3">
                <div className="font-medium">Mã {text(row.transaction_id)} · {formatVnd(Number(row.transaction_value ?? NaN))} · hoa hồng {formatVnd(Number(row.commission ?? NaN))}</div>
                <div className="text-text-2">Thời gian {formatDateTime(text(row.transaction_time))} · utm_content {text(row.utm_content)}</div>
                {click && <Badge tone={mine ? "success" : "danger"}>{mine ? "Click thuộc người khiếu nại" : "Click thuộc người dùng khác"}</Badge>}
              </li>
            );
          })}
        </ul>
      )}
    </Card>
  );
}
