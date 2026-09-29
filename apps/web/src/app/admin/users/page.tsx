import Link from "next/link";
import { DataTable } from "@/components/admin-kit/data-table";
import { PageHeader } from "@/components/admin-kit/page-header";
import { Pagination } from "@/components/admin-kit/pagination";
import { ErrorState } from "@/components/admin-kit/states";
import { FraudAlertsList } from "@/components/admin/users/fraud-alerts-list";
import { RiskFilters } from "@/components/admin/users/risk-filters";
import { RiskTable } from "@/components/admin/users/risk-table";
import { Button } from "@/components/ui/button";
import { parsePagination } from "@/lib/admin/pagination";
import { requireAdmin } from "@/lib/admin/require-admin";
import { formatDateTime, formatVnd } from "@/lib/format";
import { loadOpenFlags, loadRisk } from "./load-users";

export const dynamic = "force-dynamic";

export default async function Page({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  const sp = await searchParams;
  const { supabase } = await requireAdmin();
  const risk = sp.tab === "risk";
  const pg = parsePagination(sp);
  const tab = (href: string, label: string, active: boolean) => (
    <Button asChild variant={active ? "default" : "outline"}><Link href={href}>{label}</Link></Button>
  );

  let body;
  if (risk) {
    const r = await loadRisk(supabase, sp, pg);
    body = r.error ? <ErrorState message="Không tải được danh sách rủi ro." /> : (
      <>
        <RiskFilters searchParams={sp} />
        <RiskTable rows={r.rows} />
        <Pagination total={r.total} page={pg.page} size={pg.size} searchParams={sp} basePath="/admin/users" />
      </>
    );
  } else {
    const a = await loadOpenFlags(supabase);
    body = a.error ? <ErrorState message="Không tải được cảnh báo." /> : (
      <>
        <FraudAlertsList flags={a.flags} />
        {a.held.length > 0 && (
          <section className="mt-8">
            <h2 className="mb-2 text-lg font-semibold">Thưởng giới thiệu đang bị giữ ({a.held.length})</h2>
            <p className="mb-2 text-sm text-text-muted">Chỉ xem: chưa có thao tác duyệt / hủy thưởng phía cơ sở dữ liệu.</p>
            <DataTable rows={a.held} rowKey={(x) => x.id} columns={[
              { key: "r", header: "Người giới thiệu", cell: (x) => <Link className="text-primary underline" href={`/admin/users/${x.referrer_id}`}>{x.referrer_id.slice(0, 8)}</Link> },
              { key: "e", header: "Người được giới thiệu", cell: (x) => <Link className="text-primary underline" href={`/admin/users/${x.referee_id}`}>{x.referee_id.slice(0, 8)}</Link> },
              { key: "b", header: "Thưởng", cell: (x) => formatVnd(x.bonus_vnd) },
              { key: "d", header: "Ngày", cell: (x) => formatDateTime(x.created_at) },
            ]} />
          </section>
        )}
      </>
    );
  }

  return (
    <>
      <PageHeader title="Người dùng & Chống gian lận" description="Cảnh báo gian lận, điểm rủi ro, KYC và khóa tài khoản." />
      <nav className="mb-4 flex gap-2" aria-label="Danh sách">
        {tab("/admin/users", "Cảnh báo", !risk)}{tab("/admin/users?tab=risk", "Bảng rủi ro", risk)}
      </nav>
      {body}
    </>
  );
}
