"use client";

import { useState } from "react";
import { simulate, type SimResult } from "@/app/admin/cashback-rules/actions";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Input, Label, Select } from "@/components/ui/input";
import { formatBps, formatVnd } from "@/lib/format";
import { useRunAction } from "./use-run-action";

export function Simulator({ merchants, tiers }: { merchants: { id: string; name: string }[]; tiers: { code: string; name: string | null }[] }) {
  const [result, setResult] = useState<SimResult | null>(null);
  const { pending, run } = useRunAction();

  const submit = (fd: FormData) =>
    run(async () => {
      const r = await simulate({
        merchantId: fd.get("merchant"), categoryKey: fd.get("category") ?? "",
        orderValue: fd.get("value"), tierCode: fd.get("tier"),
      });
      setResult(r.ok ? (r.data ?? null) : null);
      return r;
    });

  const rows: [string, string][] = result ? [
    ["Hoa hồng từ sàn", `${formatVnd(result.commission_vnd)} (${formatBps(result.base_rate_bps)} giá trị đơn)`],
    ["Hoàn cơ bản", formatVnd(result.base_cashback_vnd)],
    ["Thưởng VIP", `${formatVnd(result.vip_bonus_vnd)} (${formatBps(result.vip_rate_bps)} hoa hồng)`],
    ["User nhận", formatVnd(result.user_cashback_vnd)],
    ["App giữ", formatVnd(result.app_keeps_vnd)],
  ] : [];

  return (
    <Card>
      <CardContent className="grid gap-4 lg:grid-cols-2">
        <form action={submit} className="grid gap-3">
          <div className="grid gap-1"><Label htmlFor="sim-m">Sàn</Label>
            <Select id="sim-m" name="merchant" required>{merchants.map((m) => <option key={m.id} value={m.id}>{m.name}</option>)}</Select></div>
          <div className="grid gap-1"><Label htmlFor="sim-c">Danh mục (để trống = mặc định)</Label>
            <Input id="sim-c" name="category" maxLength={64} /></div>
          <div className="grid gap-1"><Label htmlFor="sim-v">Giá trị đơn (VND)</Label>
            <Input id="sim-v" name="value" inputMode="numeric" required defaultValue="1000000" /></div>
          <div className="grid gap-1"><Label htmlFor="sim-t">Hạng VIP</Label>
            <Select id="sim-t" name="tier" required>{tiers.map((t) => <option key={t.code} value={t.code}>{t.name ?? t.code}</option>)}</Select></div>
          <Button type="submit" disabled={pending}>{pending ? "Đang tính..." : "Tính thử"}</Button>
        </form>
        <dl aria-live="polite" className="grid content-start gap-2 text-sm">
          {rows.length === 0 && <p className="text-text-muted">Kết quả dùng đúng công thức của hệ thống (estimate_cashback).</p>}
          {rows.map(([k, v]) => (
            <div key={k} className="flex justify-between border-b border-border pb-1"><dt className="text-text-muted">{k}</dt><dd className="font-medium">{v}</dd></div>
          ))}
        </dl>
      </CardContent>
    </Card>
  );
}
