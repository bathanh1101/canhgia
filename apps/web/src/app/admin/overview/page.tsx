import { FilterBar } from "@/components/admin-kit/filter-bar";
import { PageHeader } from "@/components/admin-kit/page-header";
import { ErrorState } from "@/components/admin-kit/states";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { KpiGrid } from "@/components/admin/overview/kpi-grid";
import { MerchantMixChart } from "@/components/admin/overview/merchant-mix-chart";
import { MonthlyChart } from "@/components/admin/overview/monthly-chart";
import { parseUserStats, previousRange, resolveRange } from "@/components/admin/overview/overview-logic";
import { SyncHealth } from "@/components/admin/overview/sync-health";
import { TopUsersTable } from "@/components/admin/overview/top-users-table";
import { UserStats } from "@/components/admin/overview/user-stats";
import { requireAdmin } from "@/lib/admin/require-admin";

export const dynamic = "force-dynamic";
type SP = Record<string, string | string[] | undefined>;

export default async function OverviewPage({ searchParams }: { searchParams: Promise<SP> }) {
  const { supabase } = await requireAdmin();
  const sp = await searchParams;
  const range = resolveRange(sp);
  const prev = previousRange(range);
  const args = (r: { from: string; to: string }) => ({ p_from: r.from, p_to: r.to });

  const [cur, before, series, mix, users, top, states, errors] = await Promise.all([
    supabase.rpc("admin_overview", args(range)),
    supabase.rpc("admin_overview", args(prev)),
    supabase.rpc("admin_monthly_series", { p_months: 12 }),
    supabase.rpc("admin_merchant_mix", args(range)),
    supabase.rpc("admin_user_stats", { p_days: 30 }),
    supabase.rpc("admin_top_users", { p_limit: 10 }),
    supabase.from("sync_state").select("job,last_success_at,last_error").order("job"),
    supabase.from("sync_errors").select("id,job,error,created_at").order("id", { ascending: false }).limit(50),
  ]);

  const kpi = cur.data?.[0];
  const stats = parseUserStats(users.data);
  const failed = [cur, before, series, mix, users, top, states, errors].find((r) => r.error);
  if (failed || !kpi || !stats) {
    return <ErrorState message="Không tải được số liệu tổng quan. Vui lòng thử lại." />;
  }

  return (
    <div className="space-y-6">
      <PageHeader title="Tổng quan" description={`Kỳ ${range.from} đến ${range.to}, so sánh với ${prev.from} đến ${prev.to}`} />
      <FilterBar searchParams={sp} dateRange resetHref="/admin/overview" />
      <KpiGrid current={kpi} previous={before.data?.[0]} />
      <SyncHealth
        states={states.data ?? []} errors={errors.data ?? []} errors24h={kpi.sync_errors_24h}
        unmatchedCount={kpi.unmatched_count} unmatchedRatio={Number(kpi.unmatched_ratio)}
      />
      <div className="grid gap-6 xl:grid-cols-2">
        <Card><CardHeader><CardTitle>12 tháng gần nhất</CardTitle></CardHeader>
          <CardContent><MonthlyChart data={series.data ?? []} /></CardContent></Card>
        <Card><CardHeader><CardTitle>Hoa hồng theo sàn</CardTitle></CardHeader>
          <CardContent><MerchantMixChart data={mix.data ?? []} /></CardContent></Card>
      </div>
      <UserStats stats={stats} />
      <section>
        <h2 className="mb-3 text-base font-semibold text-text">Top người dùng</h2>
        <TopUsersTable rows={top.data ?? []} />
      </section>
    </div>
  );
}
