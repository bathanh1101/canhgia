import Link from "next/link";
import { FilterBar } from "@/components/admin-kit/filter-bar";
import { PageHeader } from "@/components/admin-kit/page-header";
import { Pagination } from "@/components/admin-kit/pagination";
import { ErrorState } from "@/components/admin-kit/states";
import { Button } from "@/components/ui/button";
import { AtLookupDialog } from "@/components/admin/orders/at-lookup-dialog";
import { loadOrderDetail } from "@/components/admin/orders/order-detail-data";
import { OrderDetailSheet } from "@/components/admin/orders/order-detail-sheet";
import { CREDIT_STATES, parseOrdersFilter } from "@/components/admin/orders/orders-filter-schema";
import { withParam } from "@/components/admin/orders/orders-links";
import { buildOrdersQuery, findUserIdsByEmail, loadUserRefs } from "@/components/admin/orders/orders-query";
import { OrdersTable } from "@/components/admin/orders/orders-table";
import { parsePagination } from "@/lib/admin/pagination";
import { requireAdmin } from "@/lib/admin/require-admin";
import { statusView } from "@/lib/admin/status";

export const dynamic = "force-dynamic";
type SP = Record<string, string | string[] | undefined>;

export default async function OrdersPage({ searchParams }: { searchParams: Promise<SP> }) {
  const { supabase } = await requireAdmin();
  const sp = await searchParams;
  const filter = parseOrdersFilter(sp);
  const { page, size, from, to } = parsePagination(sp, 50);

  const [merchantsRes, matched] = await Promise.all([
    supabase.from("merchants").select("id,name").order("sort"),
    filter.q ? findUserIdsByEmail(supabase, filter.q).catch(() => null) : Promise.resolve([]),
  ]);
  const { data: rows, count, error } = await buildOrdersQuery(supabase, filter, matched ?? []).range(from, to);
  if (error || merchantsRes.error || matched === null) {
    return <ErrorState message="Không tải được danh sách đơn hàng. Vui lòng thử lại." />;
  }

  const merchants = merchantsRes.data ?? [];
  const merchantNames = new Map(merchants.map((m) => [m.id, m.name]));
  const users = await loadUserRefs(supabase, (rows ?? []).map((r) => r.user_id));
  const exportQs = withParam({ ...sp, page: undefined, order: undefined }, "order", null);

  const orderId = typeof sp.order === "string" ? sp.order : undefined;
  const selected = orderId ? (rows ?? []).find((r) => r.id === orderId) : undefined;
  const detail = selected?.id ? await loadOrderDetail(supabase, selected.id, selected.click_id).catch(() => null) : null;

  return (
    <>
      <PageHeader
        title="Đơn hàng & Đối soát"
        description={`${(count ?? 0).toLocaleString("vi-VN")} đơn khớp bộ lọc`}
        actions={
          <>
            <AtLookupDialog merchants={merchants.map((m) => ({ value: m.id, label: m.name }))} />
            <Button asChild variant="outline">
              <Link href={withParam({ ...sp, page: undefined, order: undefined }, "unmatched", filter.unmatched ? null : "1")}>
                {filter.unmatched ? "Xem tất cả" : "Chỉ chưa khớp"}
              </Link>
            </Button>
            <Button asChild><a href={`/api/admin/orders-export${exportQs}`} download>Xuất Excel</a></Button>
          </>
        }
      />
      <FilterBar
        searchParams={sp} resetHref="/admin/orders" dateRange search="Mã giao dịch hoặc email"
        merchants={merchants.map((m) => ({ value: m.id, label: m.name }))}
        statuses={CREDIT_STATES.map((s) => ({ value: s, label: statusView(s).label }))}
      />
      <OrdersTable rows={rows ?? []} users={users} merchants={merchantNames} searchParams={sp} />
      <Pagination total={count ?? 0} page={page} size={size} searchParams={sp} />
      {selected && detail && (
        <OrderDetailSheet order={selected} detail={detail} closeHref={withParam(sp, "order", null)} />
      )}
    </>
  );
}
