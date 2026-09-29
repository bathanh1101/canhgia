"use client";

import { useState, useTransition, type ReactNode } from "react";
import { Button } from "@/components/ui/button";
import {
  Dialog, DialogClose, DialogContent, DialogDescription, DialogTitle, DialogTrigger,
} from "@/components/ui/dialog";
import type { ActionResult } from "@/lib/admin/action-result";
import { notifyResult } from "./notify-result";

/**
 * Confirm-then-run. `onConfirm` is a server action (bound); its ActionResult is toasted.
 * The dialog closes on success and stays open on failure.
 */
export function ConfirmDialog({
  trigger, title, description, confirmLabel = "Xác nhận", destructive, onConfirm,
}: {
  trigger: ReactNode;
  title: string;
  description?: string;
  confirmLabel?: string;
  destructive?: boolean;
  onConfirm: () => Promise<ActionResult<unknown>>;
}) {
  const [open, setOpen] = useState(false);
  const [pending, start] = useTransition();

  const run = () =>
    start(async () => {
      try {
        const result = await onConfirm();
        notifyResult(result);
        if (result.ok) setOpen(false);
      } catch {
        notifyResult({ ok: false, error: "Đã có lỗi xảy ra. Vui lòng thử lại." });
      }
    });

  return (
    <Dialog open={open} onOpenChange={(o) => !pending && setOpen(o)}>
      <DialogTrigger asChild>{trigger}</DialogTrigger>
      <DialogContent>
        <DialogTitle>{title}</DialogTitle>
        {description && <DialogDescription>{description}</DialogDescription>}
        <div className="mt-6 flex justify-end gap-2">
          <DialogClose asChild><Button variant="outline" disabled={pending}>Hủy</Button></DialogClose>
          <Button variant={destructive ? "destructive" : "default"} onClick={run} disabled={pending}>
            {pending ? "Đang xử lý..." : confirmLabel}
          </Button>
        </div>
      </DialogContent>
    </Dialog>
  );
}
