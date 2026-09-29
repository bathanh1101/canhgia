import { StatCard } from "@/components/admin-kit/stat-card";
import { cn } from "@/lib/utils";
import { formatVnd } from "@/lib/format";
import { deltaPct } from "./overview-logic";

export interface Kpis {
  gmv_vnd: number; commission_vnd: number; paid_to_users_vnd: number; net_vnd: number; pending_commission_vnd: number;
}

function Delta({ cur, prev }: { cur: number; prev: number | undefined }) {
  const d = prev === undefined ? null : deltaPct(cur, prev);
  if (d === null) return <span>Chưa có kỳ trước để so sánh</span>;
  return (
    <span className={cn(d >= 0 ? "text-primary" : "text-danger")}>
      {d >= 0 ? "▲" : "▼"} {Math.abs(d).toLocaleString("vi-VN")}% so với kỳ trước
    </span>
  );
}

const ITEMS: { key: keyof Kpis; label: string; tip: string; delta: boolean }[] = [
  { key: "gmv_vnd", label: "GMV", tip: "Tổng giá trị đơn hàng đã cộng tiền trong kỳ", delta: true },
  { key: "commission_vnd", label: "Hoa hồng từ sàn", tip: "Hoa hồng đã duyệt (status=1, is_confirmed=1)", delta: true },
  { key: "paid_to_users_vnd", label: "Đã hoàn cho user", tip: "Cộng tiền trừ hoàn lại, gồm giới thiệu, nhiệm vụ, điều chỉnh", delta: true },
  { key: "net_vnd", label: "Lợi nhuận ròng", tip: "Hoa hồng từ sàn trừ số đã hoàn cho user", delta: true },
  { key: "pending_commission_vnd", label: "Hoa hồng chờ duyệt", tip: "Chưa được tính vào doanh thu", delta: false },
];

export function KpiGrid({ current, previous }: { current: Kpis; previous?: Kpis }) {
  return (
    <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-5">
      {ITEMS.map((i) => (
        <div key={i.key} title={i.tip}>
          <StatCard
            label={i.label} value={formatVnd(current[i.key])}
            hint={i.delta ? <Delta cur={current[i.key]} prev={previous?.[i.key]} /> : i.tip}
          />
        </div>
      ))}
    </div>
  );
}
