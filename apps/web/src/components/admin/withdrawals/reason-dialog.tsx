"use client";

import { useState, useTransition, type ReactNode } from "react";
import type { z } from "zod";
import { notifyResult } from "@/components/admin-kit/notify-result";
import { Button } from "@/components/ui/button";
import { Dialog, DialogClose, DialogContent, DialogDescription, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { Input, Label, Textarea } from "@/components/ui/input";
import type { ActionResult } from "@/lib/admin/action-result";

/** Single-field prompt (reason / reference) validated with a zod string schema before the server action runs. */
export function ReasonDialog({
  trigger, title, description, label, schema, multiline = true, confirmLabel = "Xác nhận", destructive, onSubmit,
}: {
  trigger: ReactNode;
  title: string;
  description?: string;
  label: string;
  schema: z.ZodType<string>;
  multiline?: boolean;
  confirmLabel?: string;
  destructive?: boolean;
  onSubmit: (value: string) => Promise<ActionResult<unknown>>;
}) {
  const [open, setOpen] = useState(false);
  const [value, setValue] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();

  const submit = () => {
    const parsed = schema.safeParse(value);
    if (!parsed.success) return setError("Nội dung không hợp lệ (kiểm tra độ dài tối thiểu / tối đa).");
    setError(null);
    start(async () => {
      try {
        const result = await onSubmit(parsed.data);
        notifyResult(result);
        if (result.ok) { setOpen(false); setValue(""); }
      } catch {
        notifyResult({ ok: false, error: "Đã có lỗi xảy ra. Vui lòng thử lại." });
      }
    });
  };

  const Field = multiline ? Textarea : Input;
  return (
    <Dialog open={open} onOpenChange={(o) => !pending && setOpen(o)}>
      <DialogTrigger asChild>{trigger}</DialogTrigger>
      <DialogContent>
        <DialogTitle>{title}</DialogTitle>
        {description && <DialogDescription>{description}</DialogDescription>}
        <div className="mt-4 flex flex-col gap-1">
          <Label htmlFor="reason-dialog-field">{label}</Label>
          <Field id="reason-dialog-field" value={value} onChange={(e) => setValue(e.target.value)} aria-invalid={!!error} />
          {error && <p role="alert" className="text-sm text-danger">{error}</p>}
        </div>
        <div className="mt-6 flex justify-end gap-2">
          <DialogClose asChild><Button variant="outline" disabled={pending}>Hủy</Button></DialogClose>
          <Button variant={destructive ? "destructive" : "default"} onClick={submit} disabled={pending}>
            {pending ? "Đang xử lý..." : confirmLabel}
          </Button>
        </div>
      </DialogContent>
    </Dialog>
  );
}
