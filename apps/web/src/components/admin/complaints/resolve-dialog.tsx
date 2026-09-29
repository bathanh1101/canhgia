"use client";

import { useState, useTransition } from "react";
import { notifyResult } from "@/components/admin-kit/notify-result";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogDescription, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { Input, Label, Textarea } from "@/components/ui/input";
import { resolveComplaint } from "@/app/admin/complaints/actions";
import { amountSchema, noteSchema } from "@/app/admin/complaints/schemas";
import { formatVnd } from "@/lib/format";
import { SECOND_APPROVER_THRESHOLD_VND, needsSecondApprover, type ApprovalPhase } from "./complaint-state";

export function ResolveDialog({
  reportId, maxAmount, phase, firstAmount, blockedByOrder,
}: { reportId: number; maxAmount: number; phase: ApprovalPhase; firstAmount: number | null; blockedByOrder: boolean }) {
  const [open, setOpen] = useState(false);
  const [amount, setAmount] = useState(firstAmount ? String(firstAmount) : "");
  const [note, setNote] = useState("");
  const [pending, start] = useTransition();
  if (phase === "closed") return null;

  const num = Number(amount);
  const amountOk = amountSchema.safeParse(num).success && num <= maxAmount;
  const noteOk = noteSchema.safeParse(note).success;
  const send = (decision: "approved" | "rejected") =>
    start(async () => {
      try {
        const r = await resolveComplaint(reportId, decision, num, note);
        notifyResult(r);
        if (r.ok) { setOpen(false); setNote(""); }
      } catch {
        notifyResult({ ok: false, error: "Đã có lỗi xảy ra. Vui lòng thử lại." });
      }
    });

  const canApprove = !blockedByOrder && phase !== "wait_other" && amountOk && noteOk;
  return (
    <Dialog open={open} onOpenChange={(o) => !pending && setOpen(o)}>
      <DialogTrigger asChild><Button>Xử lý khiếu nại</Button></DialogTrigger>
      <DialogContent>
        <DialogTitle>Xử lý khiếu nại</DialogTitle>
        <DialogDescription>Duyệt sẽ tạo đơn thủ công và cộng tiền hoàn vào ví. Từ chối sẽ gửi thông báo kèm lý do.</DialogDescription>
        {blockedByOrder && <p role="alert" className="mt-3 rounded-lg bg-danger-tint p-2 text-sm text-danger">Đã có đơn AccessTrade với mã này: không thể duyệt.</p>}
        {phase === "wait_other" && <p role="alert" className="mt-3 rounded-lg bg-warning-tint p-2 text-sm text-warning">Bạn đã duyệt lần 1. Cần một admin khác nhập lại đúng {formatVnd(firstAmount)} để hoàn tất.</p>}
        {phase === "second" && <p className="mt-3 rounded-lg bg-warning-tint p-2 text-sm text-warning">Admin khác đã duyệt lần 1 với {formatVnd(firstAmount)}. Nhập lại đúng số tiền này để hoàn tất.</p>}
        <div className="mt-4 flex flex-col gap-3">
          <div className="flex flex-col gap-1">
            <Label htmlFor="resolve-amount">Tiền hoàn (đ, tối đa {formatVnd(maxAmount)})</Label>
            <Input id="resolve-amount" type="number" min={1} max={maxAmount} step={1} value={amount} onChange={(e) => setAmount(e.target.value)} disabled={phase === "second"} />
            {amountOk && needsSecondApprover(num) && phase === "first" && (
              <p className="text-xs text-warning">Trên {formatVnd(SECOND_APPROVER_THRESHOLD_VND)}: cần admin thứ 2 xác nhận cùng số tiền.</p>
            )}
          </div>
          <div className="flex flex-col gap-1">
            <Label htmlFor="resolve-note">Ghi chú / lý do (5-500 ký tự)</Label>
            <Textarea id="resolve-note" value={note} onChange={(e) => setNote(e.target.value)} />
          </div>
        </div>
        <div className="mt-6 flex justify-end gap-2">
          <Button variant="destructive" disabled={pending || !noteOk} onClick={() => send("rejected")}>Từ chối</Button>
          <Button disabled={pending || !canApprove} onClick={() => send("approved")}>{pending ? "Đang xử lý..." : "Duyệt"}</Button>
        </div>
      </DialogContent>
    </Dialog>
  );
}
