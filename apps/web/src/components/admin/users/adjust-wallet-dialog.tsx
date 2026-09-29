"use client";

import { useState, useTransition, type ReactNode } from "react";
import { notifyResult } from "@/components/admin-kit/notify-result";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogDescription, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { Input, Label, Textarea } from "@/components/ui/input";
import { adjustWallet } from "@/app/admin/users/actions";
import { adjustAmountSchema, reasonSchema } from "@/app/admin/users/schemas";
import { formatVnd } from "@/lib/format";

/** Two steps in one dialog: fill in, then an explicit confirmation of the money movement. */
export function AdjustWalletDialog({ userId, trigger }: { userId: string; trigger: ReactNode }) {
  const [open, setOpen] = useState(false);
  const [amount, setAmount] = useState("");
  const [reason, setReason] = useState("");
  const [confirming, setConfirming] = useState(false);
  const [pending, start] = useTransition();
  const parsedAmount = adjustAmountSchema.safeParse(Number(amount));
  const valid = parsedAmount.success && reasonSchema.safeParse(reason).success;

  const reset = () => { setOpen(false); setConfirming(false); setAmount(""); setReason(""); };
  const submit = () =>
    start(async () => {
      try {
        const r = await adjustWallet(userId, Number(amount), reason);
        notifyResult(r);
        if (r.ok) reset();
      } catch {
        notifyResult({ ok: false, error: "Đã có lỗi xảy ra. Vui lòng thử lại." });
      }
    });

  return (
    <Dialog open={open} onOpenChange={(o) => !pending && (o ? setOpen(true) : reset())}>
      <DialogTrigger asChild>{trigger}</DialogTrigger>
      <DialogContent>
        <DialogTitle>Điều chỉnh ví</DialogTitle>
        <DialogDescription>Số dương để cộng, số âm để trừ. Đây là cách duy nhất để đưa ví về âm; thao tác được ghi nhật ký.</DialogDescription>
        {confirming && parsedAmount.success ? (
          <p className="mt-4 rounded-lg bg-warning-tint p-3 text-sm text-warning">
            Xác nhận {parsedAmount.data > 0 ? "cộng" : "trừ"} {formatVnd(Math.abs(parsedAmount.data))} {parsedAmount.data > 0 ? "vào" : "khỏi"} ví. Lý do: {reason}
          </p>
        ) : (
          <div className="mt-4 flex flex-col gap-3">
            <div className="flex flex-col gap-1">
              <Label htmlFor="adj-amount">Số tiền (đ)</Label>
              <Input id="adj-amount" type="number" step={1} value={amount} onChange={(e) => setAmount(e.target.value)} />
            </div>
            <div className="flex flex-col gap-1">
              <Label htmlFor="adj-reason">Lý do (5-500 ký tự)</Label>
              <Textarea id="adj-reason" value={reason} onChange={(e) => setReason(e.target.value)} />
            </div>
          </div>
        )}
        <div className="mt-6 flex justify-end gap-2">
          <Button variant="outline" disabled={pending} onClick={() => (confirming ? setConfirming(false) : reset())}>{confirming ? "Quay lại" : "Hủy"}</Button>
          {confirming ? (
            <Button variant="destructive" disabled={pending} onClick={submit}>{pending ? "Đang xử lý..." : "Xác nhận điều chỉnh"}</Button>
          ) : (
            <Button disabled={!valid} onClick={() => setConfirming(true)}>Tiếp tục</Button>
          )}
        </div>
      </DialogContent>
    </Dialog>
  );
}
