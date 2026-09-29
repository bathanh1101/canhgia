"use client";

import { updateTier } from "@/app/admin/cashback-rules/actions";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { bpsToPercent } from "./rules-logic";
import { useRunAction } from "./use-run-action";

export interface Tier { code: string; name: string | null; min_gmv_12m_vnd: number; bonus_bps: number }

function TierRow({ tier }: { tier: Tier }) {
  const { pending, run } = useRunAction();
  const submit = (fd: FormData) =>
    run(() => updateTier({ code: tier.code, bonusPercent: String(fd.get("bonus") ?? ""), minGmv: String(fd.get("gmv") ?? "") }));
  return (
    <TableRow>
      <TableCell className="font-medium">{tier.name ?? tier.code}</TableCell>
      <TableCell colSpan={3}>
        <form action={submit} className="flex flex-wrap items-center gap-2">
          <Input aria-label={`GMV 12 tháng tối thiểu ${tier.code}`} name="gmv" inputMode="numeric" className="w-44" defaultValue={String(tier.min_gmv_12m_vnd)} />
          <Input aria-label={`Thưởng VIP % hoa hồng ${tier.code}`} name="bonus" inputMode="decimal" className="w-28" defaultValue={bpsToPercent(tier.bonus_bps)} />
          <Button type="submit" size="sm" disabled={pending}>Lưu</Button>
        </form>
      </TableCell>
    </TableRow>
  );
}

export function VipTiersTable({ tiers }: { tiers: Tier[] }) {
  return (
    <Card className="overflow-hidden">
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Hạng</TableHead>
            <TableHead>GMV 12 tháng tối thiểu (VND)</TableHead>
            <TableHead>Thưởng (% hoa hồng)</TableHead>
            <TableHead />
          </TableRow>
        </TableHeader>
        <TableBody>{tiers.map((t) => <TierRow key={t.code} tier={t} />)}</TableBody>
      </Table>
    </Card>
  );
}
