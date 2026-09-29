"use client";

import { useState } from "react";
import { upsertRule } from "@/app/admin/cashback-rules/actions";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogDescription, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { Input, Label } from "@/components/ui/input";
import { bpsToPercent, type RuleRow } from "./rules-logic";
import { useRunAction } from "./use-run-action";

export function RuleEditDialog({ row, maxShareBps }: { row: RuleRow; maxShareBps: number }) {
  const [open, setOpen] = useState(false);
  const { pending, run } = useRunAction();

  const submit = (fd: FormData) =>
    run(
      () => upsertRule({
        merchantId: row.merchantId, categoryKey: row.categoryKey,
        sharePercent: String(fd.get("share") ?? ""), enabled: true, note: String(fd.get("note") ?? ""),
      }),
      () => setOpen(false),
    );

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild><Button variant="outline" size="sm">Sửa</Button></DialogTrigger>
      <DialogContent>
        <DialogTitle>Tỷ lệ hoàn: {row.merchantName}{row.categoryKey ? ` / ${row.categoryKey}` : ""}</DialogTitle>
        <DialogDescription>
          Phần trăm hoa hồng chia cho user, tối đa {bpsToPercent(maxShareBps)}% để cộng với thưởng VIP không vượt 100%.
        </DialogDescription>
        <form action={submit} className="mt-4 grid gap-3">
          <div className="grid gap-1">
            <Label htmlFor="rule-share">Hoàn user (% hoa hồng)</Label>
            <Input id="rule-share" name="share" inputMode="decimal" required defaultValue={bpsToPercent(row.shareBps)} />
          </div>
          <div className="grid gap-1">
            <Label htmlFor="rule-note">Ghi chú</Label>
            <Input id="rule-note" name="note" maxLength={200} />
          </div>
          <Button type="submit" disabled={pending}>{pending ? "Đang lưu..." : "Lưu"}</Button>
        </form>
      </DialogContent>
    </Dialog>
  );
}
