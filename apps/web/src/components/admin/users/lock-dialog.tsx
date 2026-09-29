"use client";

import type { ReactNode } from "react";
import { ConfirmDialog } from "@/components/admin-kit/confirm-dialog";
import { ReasonDialog } from "@/components/admin/withdrawals/reason-dialog";
import { setUserLock } from "@/app/admin/users/actions";
import { reasonSchema } from "@/app/admin/users/schemas";

/** Lock asks for a reason (stored on user_risk.lock_reason); unlock is a plain confirmation. */
export function LockDialog({ userId, locked, trigger }: { userId: string; locked: boolean; trigger: ReactNode }) {
  if (locked) {
    return (
      <ConfirmDialog
        trigger={trigger} title="Mở khóa tài khoản" description="Người dùng sẽ tạo link và rút tiền được trở lại." confirmLabel="Mở khóa"
        onConfirm={() => setUserLock(userId, false, "")}
      />
    );
  }
  return (
    <ReasonDialog
      trigger={trigger} title="Khóa tài khoản" description="Người dùng không thể tạo link hoặc rút tiền khi bị khóa."
      label="Lý do khóa (5-500 ký tự)" schema={reasonSchema} destructive confirmLabel="Khóa"
      onSubmit={(reason) => setUserLock(userId, true, reason)}
    />
  );
}
