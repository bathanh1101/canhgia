"use client";

import { useState, useTransition } from "react";
import { atLookup } from "@/app/admin/orders/actions";
import { notifyResult } from "@/components/admin-kit/notify-result";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogDescription, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { Input, Label, Select } from "@/components/ui/input";
import type { AtLookupResult } from "./orders-action-schemas";

/** Look up a missing order directly at AccessTrade (Edge admin-at-lookup). */
export function AtLookupDialog({ merchants }: { merchants: { value: string; label: string }[] }) {
  const [result, setResult] = useState<AtLookupResult | null>(null);
  const [pending, start] = useTransition();

  const submit = (fd: FormData) =>
    start(async () => {
      try {
        const r = await atLookup({
          merchant_id: fd.get("merchant_id"), order_code: fd.get("order_code"), purchased_on: fd.get("purchased_on"),
        });
        if (r.ok) setResult(r.data ?? null);
        else notifyResult(r);
      } catch {
        notifyResult({ ok: false, error: "Đã có lỗi xảy ra. Vui lòng thử lại." });
      }
    });

  return (
    <Dialog>
      <DialogTrigger asChild><Button variant="outline">Tra cứu AccessTrade</Button></DialogTrigger>
      <DialogContent className="max-h-[85vh] overflow-y-auto">
        <DialogTitle>Tra cứu đơn tại AccessTrade</DialogTitle>
        <DialogDescription>Nhập mã đơn và ngày mua để tìm giao dịch và click liên quan.</DialogDescription>
        <form action={submit} className="mt-4 grid gap-3">
          <div className="grid gap-1"><Label htmlFor="at-m">Sàn</Label>
            <Select id="at-m" name="merchant_id" required>
              {merchants.map((m) => <option key={m.value} value={m.value}>{m.label}</option>)}
            </Select></div>
          <div className="grid gap-1"><Label htmlFor="at-c">Mã đơn hàng</Label>
            <Input id="at-c" name="order_code" required maxLength={100} /></div>
          <div className="grid gap-1"><Label htmlFor="at-d">Ngày mua</Label>
            <Input id="at-d" name="purchased_on" type="date" required /></div>
          <Button type="submit" disabled={pending}>{pending ? "Đang tra cứu..." : "Tra cứu"}</Button>
        </form>
        {result && (
          <div className="mt-4 space-y-3 text-sm">
            <p className="font-medium">{result.rows.length} giao dịch · {result.clicks.length} click</p>
            {result.clicks.map((c) => (
              <p key={c.id} className="rounded-lg bg-bg p-2">
                Click #{c.id} · user {c.user_id?.slice(0, 8) ?? "-"} · {c.source} · {c.status}
              </p>
            ))}
            <pre className="max-h-64 overflow-auto rounded-lg bg-bg p-2 text-xs">{JSON.stringify(result.rows, null, 2)}</pre>
          </div>
        )}
      </DialogContent>
    </Dialog>
  );
}
