"use client";

import { useRouter } from "next/navigation";
import { Dialog, DialogContent, DialogDescription, DialogTitle } from "@/components/ui/dialog";
import { formatDateTime, formatVnd } from "@/lib/format";
import type { OrderDetail } from "./order-detail-data";
import type { OrderRow } from "./orders-table";

/** Detail dialog driven by `?order=<id>`; closing navigates back to the same list without the param. */
export function OrderDetailSheet({ order, detail, closeHref }: { order: OrderRow; detail: OrderDetail; closeHref: string }) {
  const router = useRouter();
  return (
    <Dialog open onOpenChange={(o) => { if (!o) router.push(closeHref); }}>
      <DialogContent className="max-h-[85vh] overflow-y-auto">
        <DialogTitle>Đơn {order.transaction_id}</DialogTitle>
        <DialogDescription>
          {order.merchant_id} · {formatDateTime(order.order_time)} · rút được từ {formatDateTime(order.withdrawable_at)}
        </DialogDescription>
        <section className="mt-4 text-sm">
          <h3 className="font-medium">Click</h3>
          {detail.click ? (
            <p>#{detail.click.id} · {detail.click.source} · {detail.click.status} · {formatDateTime(detail.click.created_at)}</p>
          ) : (
            <p className="text-text-muted">Không có click liên kết (khớp {order.matched_by ?? "-"}).</p>
          )}
        </section>
        <section className="mt-4 text-sm">
          <h3 className="font-medium">Sổ cái ví</h3>
          {detail.ledger.length === 0 ? <p className="text-text-muted">Chưa có bút toán.</p> : (
            <ul className="divide-y divide-border">
              {detail.ledger.map((l) => (
                <li key={l.id} className="flex justify-between py-1">
                  <span>{l.entry_type} · {formatDateTime(l.created_at)}</span>
                  <b>{formatVnd(l.amount_vnd)}</b>
                </li>
              ))}
            </ul>
          )}
        </section>
        <details className="mt-4 text-sm">
          <summary className="cursor-pointer font-medium">Dữ liệu gốc AccessTrade (order_raw)</summary>
          <pre className="mt-2 max-h-72 overflow-auto rounded-lg bg-bg p-2 text-xs">{JSON.stringify(detail.raw, null, 2) ?? "null"}</pre>
        </details>
      </DialogContent>
    </Dialog>
  );
}
