import { FilterBar } from "@/components/admin-kit/filter-bar";
import { PageHeader } from "@/components/admin-kit/page-header";
import { Pagination } from "@/components/admin-kit/pagination";
import { ErrorState } from "@/components/admin-kit/states";
import { COMPLAINT_STATUSES } from "@/components/admin/complaints/complaint-state";
import { ComplaintsTable } from "@/components/admin/complaints/complaints-table";
import { parsePagination } from "@/lib/admin/pagination";
import { requireAdmin } from "@/lib/admin/require-admin";

export const dynamic = "force-dynamic";

const first = (v: string | string[] | undefined) => (Array.isArray(v) ? v[0] : v) ?? "";
const DATE = /^\d{4}-\d{2}-\d{2}$/;

export default async function Page({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  const sp = await searchParams;
  const { supabase } = await requireAdmin();
  const pg = parsePagination(sp);
  const status = first(sp.status);
  const merchant = first(sp.merchant);
  const from = first(sp.from);
  const to = first(sp.to);

  let q = supabase.from("missing_order_reports")
    .select("id,public_code,user_id,merchant_id,order_code,order_value_vnd,purchased_on,status,created_at,first_approved_by", { count: "exact" })
    .order("created_at", { ascending: false }).range(pg.from, pg.to);
  if (COMPLAINT_STATUSES.some((s) => s.value === status)) q = q.eq("status", status);
  if (merchant) q = q.eq("merchant_id", merchant);
  if (DATE.test(from)) q = q.gte("created_at", `${from}T00:00:00+07:00`);
  if (DATE.test(to)) q = q.lte("created_at", `${to}T23:59:59+07:00`);

  const [list, merchants] = await Promise.all([q, supabase.from("merchants").select("id,name").order("sort")]);
  const ids = [...new Set((list.data ?? []).map((r) => r.user_id))];
  const profiles = ids.length ? await supabase.from("profiles").select("id,email").in("id", ids) : { data: [], error: null };
  const error = list.error ?? merchants.error ?? profiles.error;

  const email = new Map((profiles.data ?? []).map((p) => [p.id, p.email ?? ""]));
  const mName = new Map((merchants.data ?? []).map((m) => [m.id, m.name]));
  const rows = (list.data ?? []).map((r) => ({ ...r, email: email.get(r.user_id) ?? "", merchantName: mName.get(r.merchant_id) ?? r.merchant_id }));

  return (
    <>
      <PageHeader title="Xử lý khiếu nại" description="Khiếu nại đơn hàng không được ghi nhận." />
      <FilterBar
        searchParams={sp} statuses={COMPLAINT_STATUSES} dateRange resetHref="/admin/complaints"
        merchants={(merchants.data ?? []).map((m) => ({ value: m.id, label: m.name }))}
      />
      {error ? <ErrorState message="Không tải được danh sách khiếu nại." /> : (
        <>
          <ComplaintsTable rows={rows} />
          <Pagination total={list.count ?? 0} page={pg.page} size={pg.size} searchParams={sp} basePath="/admin/complaints" />
        </>
      )}
    </>
  );
}
