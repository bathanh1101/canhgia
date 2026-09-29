"use client";

import { useState, useTransition } from "react";
import { notifyResult } from "@/components/admin-kit/notify-result";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Checkbox } from "@/components/ui/checkbox";
import { Input, Label } from "@/components/ui/input";
import { savePayoutSettings } from "@/app/admin/withdrawals/actions";

export interface PayoutSettings { autoEnabled: boolean; autoLimit: number; dailyCap: number }

export function PayoutSettingsCard({ initial }: { initial: PayoutSettings }) {
  const [s, setS] = useState({ ...initial, autoLimit: String(initial.autoLimit), dailyCap: String(initial.dailyCap) });
  const [pending, start] = useTransition();

  const save = () =>
    start(async () => {
      try {
        notifyResult(await savePayoutSettings({ autoEnabled: s.autoEnabled, autoLimit: Number(s.autoLimit), dailyCap: Number(s.dailyCap) }));
      } catch {
        notifyResult({ ok: false, error: "Đã có lỗi xảy ra. Vui lòng thử lại." });
      }
    });

  return (
    <Card className="mb-4 p-4">
      <div className="flex flex-wrap items-end gap-4">
        <div className="flex items-center gap-2">
          <Checkbox id="auto-payout" checked={s.autoEnabled} onCheckedChange={(c) => setS({ ...s, autoEnabled: c === true })} />
          <Label htmlFor="auto-payout">Tự động chi trả</Label>
          <Badge tone="warning">Chưa kích hoạt (MVP)</Badge>
        </div>
        <div className="flex flex-col gap-1">
          <Label htmlFor="auto-limit">Hạn mức tự động (đ)</Label>
          <Input id="auto-limit" type="number" min={0} step={1000} value={s.autoLimit} onChange={(e) => setS({ ...s, autoLimit: e.target.value })} />
        </div>
        <div className="flex flex-col gap-1">
          <Label htmlFor="daily-cap">Hạn mức rút mỗi ngày (đ)</Label>
          <Input id="daily-cap" type="number" min={0} step={1000} value={s.dailyCap} onChange={(e) => setS({ ...s, dailyCap: e.target.value })} />
        </div>
        <Button onClick={save} disabled={pending}>{pending ? "Đang lưu..." : "Lưu"}</Button>
      </div>
      <p className="mt-2 text-xs text-text-muted">
        Tự động chi trả chỉ lưu cài đặt, chưa có tác dụng: mọi khoản rút hiện được chuyển khoản thủ công qua VietQR. Hạn mức mỗi ngày được áp dụng khi người dùng rút tiền.
      </p>
    </Card>
  );
}
