"use client";

import { useState } from "react";
import { assignOrder } from "@/app/admin/orders/actions";
import { ConfirmDialog } from "@/components/admin-kit/confirm-dialog";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogDescription, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import type { UserRef } from "./orders-query";
import { UserSearch } from "./user-search";

export function AssignUserDialog({ orderId, currentUser }: { orderId: string; currentUser: string | null }) {
  const [open, setOpen] = useState(false);
  const [picked, setPicked] = useState<UserRef | null>(null);

  return (
    <Dialog open={open} onOpenChange={(o) => { setOpen(o); if (!o) setPicked(null); }}>
      <DialogTrigger asChild><Button variant="outline" size="sm">Gán user</Button></DialogTrigger>
      <DialogContent>
        <DialogTitle>Gán đơn hàng cho người dùng</DialogTitle>
        <DialogDescription>
          {currentUser
            ? `Đơn đang thuộc ${currentUser}. Khoản đã cộng sẽ được thu hồi và người đó nhận thông báo.`
            : "Đơn chưa khớp người dùng nào."}
        </DialogDescription>
        <div className="mt-4"><UserSearch onPick={setPicked} /></div>
        {picked && (
          <div className="mt-4 flex items-center justify-between gap-2 rounded-lg bg-primary-tint p-3 text-sm">
            <span>Đã chọn: <b>{picked.email}</b> · #{picked.short_id}</span>
            <ConfirmDialog
              trigger={<Button size="sm">Gán</Button>}
              title="Xác nhận gán đơn hàng"
              description={`Gán đơn cho ${picked.email ?? picked.id} (mã #${picked.short_id})? Thao tác được ghi audit log.`}
              confirmLabel="Gán đơn"
              onConfirm={async () => {
                const r = await assignOrder(orderId, picked.id);
                if (r.ok) setOpen(false);
                return r;
              }}
            />
          </div>
        )}
      </DialogContent>
    </Dialog>
  );
}
