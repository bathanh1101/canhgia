"use client";

import { Bar, CartesianGrid, ComposedChart, Legend, Line, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts";
import { formatVnd } from "@/lib/format";

export interface MonthPoint { month: string; commission_vnd: number; paid_vnd: number; net_vnd: number }

const short = (n: number) => (Math.abs(n) >= 1e6 ? `${(n / 1e6).toFixed(1)}tr` : `${Math.round(n / 1e3)}k`);

export function MonthlyChart({ data }: { data: MonthPoint[] }) {
  const rows = data.map((d) => ({ ...d, label: d.month.slice(0, 7) }));
  return (
    <div className="h-72 w-full" role="img" aria-label="Biểu đồ hoa hồng, hoàn user và lợi nhuận 12 tháng">
      <ResponsiveContainer width="100%" height="100%">
        <ComposedChart data={rows}>
          <CartesianGrid strokeDasharray="3 3" stroke="var(--color-border)" />
          <XAxis dataKey="label" fontSize={12} />
          <YAxis tickFormatter={short} fontSize={12} width={48} />
          <Tooltip formatter={(v) => formatVnd(Number(v))} />
          <Legend />
          <Bar dataKey="commission_vnd" name="Hoa hồng" fill="var(--color-primary)" />
          <Bar dataKey="paid_vnd" name="Hoàn user" fill="var(--color-warning)" />
          <Line dataKey="net_vnd" name="Lợi nhuận ròng" stroke="var(--color-info)" strokeWidth={2} dot={false} />
        </ComposedChart>
      </ResponsiveContainer>
    </div>
  );
}
