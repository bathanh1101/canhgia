"use client";

import Link from "next/link";
import { ConfirmDialog } from "@/components/admin-kit/confirm-dialog";
import { Button } from "@/components/ui/button";
import { updateFlag } from "@/app/admin/users/actions";
import { AdjustWalletDialog } from "./adjust-wallet-dialog";
import { LockDialog } from "./lock-dialog";

export function FlagActions({ flagId, userId, type, locked }: { flagId: number; userId: string | null; type: string; locked: boolean }) {
  return (
    <div className="flex flex-wrap gap-2">
      <ConfirmDialog
        trigger={<Button size="sm" variant="outline">Bỏ cảnh báo</Button>} title="Bỏ cảnh báo này?"
        description="Cảnh báo được đánh dấu bỏ qua và không xuất hiện trong danh sách đang mở."
        onConfirm={() => updateFlag(flagId, "dismissed")}
      />
      {userId && (
        <>
          <LockDialog userId={userId} locked={locked} trigger={<Button size="sm" variant="destructive">{locked ? "Mở khóa" : "Khóa tài khoản"}</Button>} />
          {type === "negative_balance_risk" && <AdjustWalletDialog userId={userId} trigger={<Button size="sm">Điều chỉnh ví</Button>} />}
        </>
      )}
      {type === "order_claim_conflict" && <Button asChild size="sm" variant="outline"><Link href="/admin/complaints">Xem khiếu nại</Link></Button>}
      <ConfirmDialog
        trigger={<Button size="sm" variant="outline">Đã xử lý</Button>} title="Đánh dấu đã xử lý?"
        onConfirm={() => updateFlag(flagId, "actioned")}
      />
    </div>
  );
}
