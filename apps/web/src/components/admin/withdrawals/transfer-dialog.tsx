"use client";

import { useState, useTransition } from "react";
import { notifyResult } from "@/components/admin-kit/notify-result";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogDescription, DialogTitle } from "@/components/ui/dialog";
import { Input, Label } from "@/components/ui/input";
import { markPaid, rejectWithdrawals, verifyBankAccount } from "@/app/admin/withdrawals/actions";
import { reasonSchema, transferRefSchema } from "@/app/admin/withdrawals/schemas";
import { formatVnd } from "@/lib/format";
import { ReasonDialog } from "./reason-dialog";
import type { WithdrawalRow } from "./types";
import { transferMemo } from "./withdrawal-state";
import { VietQrImage } from "./vietqr-image";

const Field = ({ k, v }: { k: string; v: string }) => (
  <div className="flex justify-between gap-4 text-sm"><dt className="text-text-muted">{k}</dt><dd className="text-right font-medium text-text">{v}</dd></div>
);

/** Opened after a successful claim. Full account number is shown only here. */
export function TransferDialog({ row, onClose }: { row: WithdrawalRow; onClose: () => void }) {
  const [ref, setRef] = useState("");
  const [pending, start] = useTransition();
  const run = (fn: () => Promise<Parameters<typeof notifyResult>[0]>, closeOnOk = false) =>
    start(async () => {
      try {
        const r = await fn();
        notifyResult(r);
        if (r.ok && closeOnOk) onClose();
      } catch {
        notifyResult({ ok: false, error: "Đã có lỗi xảy ra. Vui lòng thử lại." });
      }
    });
  const nameMismatch = row.kycName !== null && row.kycName.trim().toUpperCase() !== row.accountName.trim().toUpperCase();
  const refOk = transferRefSchema.safeParse(ref).success;

  return (
    <Dialog open onOpenChange={(o) => !o && !pending && onClose()}>
      <DialogContent className="max-w-2xl">
        <DialogTitle>Chuyển khoản {formatVnd(row.amount)}</DialogTitle>
        <DialogDescription>
          Quét mã bằng app ngân hàng, đối chiếu tên người nhận với tên KYC rồi chuyển khoản. Sau đó nhập mã giao dịch của ngân hàng.
        </DialogDescription>
        <div className="mt-4 grid gap-6 md:grid-cols-[280px_1fr]">
          <VietQrImage bin={row.bankBin} account={row.accountNumber} amount={row.amount} addInfo={transferMemo(row.id)} />
          <dl className="flex flex-col gap-2">
            <Field k="Ngân hàng" v={`${row.bankName} (${row.bankBin})`} />
            <Field k="Số tài khoản" v={row.accountNumber} />
            <Field k="Tên chủ TK (lúc thêm)" v={row.accountName} />
            <Field k="Tên KYC" v={row.kycName ?? "Chưa có KYC"} />
            <Field k="Nội dung" v={transferMemo(row.id)} />
            {nameMismatch && <p role="alert" className="rounded-lg bg-warning-tint p-2 text-xs text-warning">Tên chủ TK khác tên KYC. Kiểm tra kỹ trước khi chuyển.</p>}
            {!row.bankVerified && (
              <Button variant="outline" disabled={pending} onClick={() => run(() => verifyBankAccount(row.bankAccountId))}>
                Xác nhận tên chủ TK khớp
              </Button>
            )}
            <div className="mt-2 flex flex-col gap-1">
              <Label htmlFor="transfer-ref">Mã giao dịch ngân hàng</Label>
              <Input id="transfer-ref" value={ref} maxLength={64} onChange={(e) => setRef(e.target.value)} placeholder="VD: FT26100512345" />
            </div>
          </dl>
        </div>
        <div className="mt-6 flex justify-end gap-2">
          <ReasonDialog
            trigger={<Button variant="destructive" disabled={pending}>Từ chối</Button>}
            title="Từ chối yêu cầu rút tiền" description="Số tiền sẽ được hoàn lại vào ví người dùng." label="Lý do (5-500 ký tự)"
            schema={reasonSchema} destructive confirmLabel="Từ chối"
            onSubmit={async (reason) => {
              const r = await rejectWithdrawals([row.id], reason);
              if (r.ok) onClose();
              return r;
            }}
          />
          <Button disabled={pending || !refOk || !row.bankVerified} onClick={() => run(() => markPaid([row.id], ref), true)}>
            {pending ? "Đang xử lý..." : "Đã chuyển"}
          </Button>
        </div>
        {!row.bankVerified && <p className="mt-2 text-right text-xs text-text-muted">Cần xác nhận tên chủ tài khoản trước khi đánh dấu đã chuyển.</p>}
      </DialogContent>
    </Dialog>
  );
}
