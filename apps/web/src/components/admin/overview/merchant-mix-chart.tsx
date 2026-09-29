"use client";

import { Bar, BarChart, CartesianGrid, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts";
import { formatVnd } from "@/lib/format";

export interface MixPoint { merchant_id: string; commission_vnd: number; share: number }

export function MerchantMixChart({ data }: { data: MixPoint[] }) {
  if (data.length === 0) return <p className="py-8 text-center text-sm text-text-muted">Chưa có hoa hồng trong kỳ.</p>;
  return (
    <div className="h-72 w-full" role="img" aria-label="Cơ cấu hoa hồng theo sàn">
      <ResponsiveContainer width="100%" height="100%">
        <BarChart data={data} layout="vertical" margin={{ left: 16 }}>
          <CartesianGrid strokeDasharray="3 3" stroke="var(--color-border)" />
          <XAxis type="number" hide />
          <YAxis type="category" dataKey="merchant_id" width={80} fontSize={12} />
          <Tooltip formatter={(v, _n, p) => `${formatVnd(Number(v))} (${(Number(p.payload.share) * 100).toFixed(1)}%)`} />
          <Bar dataKey="commission_vnd" name="Hoa hồng" fill="var(--color-primary)" />
        </BarChart>
      </ResponsiveContainer>
    </div>
  );
}
