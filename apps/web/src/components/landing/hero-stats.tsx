import type { LandingStats } from "@/lib/landing/schema";

/** Social proof strictly from `landing_stats`; missing field = stat hidden, all missing = block hidden. */
export function HeroStats({ stats }: { stats: LandingStats | null | undefined }) {
  if (!stats) return null;
  const items = [
    stats.rating !== undefined && { value: `★ ${stats.rating.toLocaleString("vi-VN")}`, label: "Điểm đánh giá" },
    stats.users && { value: stats.users, label: "Người dùng" },
    stats.refunded && { value: stats.refunded, label: "Đã hoàn cho khách" },
  ].filter((x): x is { value: string; label: string } => Boolean(x));
  if (items.length === 0) return null;
  return (
    <dl className="mt-10 flex flex-wrap gap-10">
      {items.map((i) => (
        <div key={i.label}>
          <dd className="text-2xl font-bold text-text">{i.value}</dd>
          <dt className="text-sm text-text-muted">{i.label}</dt>
        </div>
      ))}
    </dl>
  );
}
