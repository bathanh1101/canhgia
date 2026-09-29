"use client";

import { saveSetting } from "@/app/admin/cashback-rules/actions";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Input, Label } from "@/components/ui/input";
import { NUMERIC_SETTINGS, readLandingStats, type NumericSettingKey } from "./settings-logic";
import type { Json } from "@/lib/supabase/database.types";
import { useRunAction } from "./use-run-action";

function SettingForm({ k, label, children }: { k: string; label: string; children: React.ReactNode }) {
  const { pending, run } = useRunAction();
  const submit = (fd: FormData) => run(() => saveSetting(k, Object.fromEntries([...fd].map(([a, b]) => [a, String(b)]))));
  return (
    <form action={submit} className="flex flex-wrap items-end gap-3 border-b border-border pb-4 last:border-0">
      <div className="min-w-56 flex-1 space-y-1"><p className="text-sm font-medium text-text-2">{label}</p>
        <div className="flex flex-wrap gap-2">{children}</div></div>
      <Button type="submit" size="sm" disabled={pending}>Lưu</Button>
    </form>
  );
}

export function SettingsEditor({ values }: { values: Record<string, Json> }) {
  const landing = readLandingStats(values.landing_stats);
  return (
    <Card>
      <CardContent className="space-y-4">
        {(Object.keys(NUMERIC_SETTINGS) as NumericSettingKey[]).map((k) => (
          <SettingForm key={k} k={k} label={NUMERIC_SETTINGS[k]}>
            <Input aria-label={NUMERIC_SETTINGS[k]} name="value" inputMode="numeric" defaultValue={String(values[k] ?? "")} />
          </SettingForm>
        ))}
        <SettingForm k="withdraw_eta_text" label="Thời gian nhận tiền hiển thị cho user">
          <Input aria-label="Thời gian nhận tiền" name="value" maxLength={100} defaultValue={typeof values.withdraw_eta_text === "string" ? values.withdraw_eta_text : ""} />
        </SettingForm>
        <SettingForm k="landing_stats" label="Số liệu trang chủ (để trống hết = ẩn)">
          <div className="grid gap-1"><Label htmlFor="ls-r">Đánh giá (0-5)</Label><Input id="ls-r" name="rating" inputMode="decimal" className="w-28" defaultValue={landing.rating} /></div>
          <div className="grid gap-1"><Label htmlFor="ls-u">Người dùng</Label><Input id="ls-u" name="users" maxLength={32} className="w-36" defaultValue={landing.users} /></div>
          <div className="grid gap-1"><Label htmlFor="ls-f">Đã hoàn</Label><Input id="ls-f" name="refunded" maxLength={32} className="w-36" defaultValue={landing.refunded} /></div>
        </SettingForm>
      </CardContent>
    </Card>
  );
}
