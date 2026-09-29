import { StatCard } from "@/components/admin-kit/stat-card";
import { sparklinePoints, type UserStatsData } from "./overview-logic";

export function UserStats({ stats }: { stats: UserStatsData }) {
  const last = stats.dau.at(-1)?.count ?? 0;
  return (
    <div className="grid gap-4 sm:grid-cols-3">
      <StatCard label="Người dùng mới (tháng này)" value={stats.newUsersMonth.toLocaleString("vi-VN")} />
      <StatCard
        label="Giữ chân D30"
        value={`${(stats.d30Retention * 100).toLocaleString("vi-VN", { maximumFractionDigits: 1 })}%`}
        hint="Người dùng đăng ký 30-60 ngày trước còn hoạt động sau ngày thứ 30"
      />
      <StatCard
        label="DAU hôm nay"
        value={last.toLocaleString("vi-VN")}
        hint={
          <svg viewBox="0 0 120 32" className="h-8 w-full" role="img" aria-label="DAU 30 ngày">
            <polyline fill="none" stroke="var(--color-primary)" strokeWidth="2" points={sparklinePoints(stats.dau.map((d) => d.count))} />
          </svg>
        }
      />
    </div>
  );
}
