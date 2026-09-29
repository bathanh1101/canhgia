import Link from "next/link";
import { PageHeader } from "@/components/admin-kit/page-header";
import { Pagination } from "@/components/admin-kit/pagination";
import { ErrorState } from "@/components/admin-kit/states";
import { PayoutSettingsCard } from "@/components/admin/withdrawals/payout-settings-card";
import { WithdrawalHistoryTable } from "@/components/admin/withdrawals/withdrawal-history-table";
import { WithdrawalsTable } from "@/components/admin/withdrawals/withdrawals-table";
import { Button } from "@/components/ui/button";
import { parsePagination } from "@/lib/admin/pagination";
import { requireAdmin } from "@/lib/admin/require-admin";
import { loadWithdrawals } from "./load-withdrawals";

export const dynamic = "force-dynamic";

const num = (v: unknown, fallback: number) => (typeof v === "number" && Number.isFinite(v) ? v : fallback);

export default async function Page({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  const sp = await searchParams;
  const { supabase, adminId } = await requireAdmin();
  const history = sp.tab === "history";
  const pg = parsePagination(sp);

  const [list, settings] = await Promise.all([
    history
      ? loadWithdrawals(supabase, ["paid", "rejected"], pg)
      : loadWithdrawals(supabase, ["pending", "processing"]),
    supabase.from("app_settings").select("key,value")
      .in("key", ["auto_payout_enabled", "auto_payout_limit_vnd", "withdraw_daily_cap_vnd"]),
  ]);
  const cfg = new Map((settings.data ?? []).map((s) => [s.key, s.value]));

  return (
    <>
      <PageHeader title="Duyệt rút tiền" description="Chuyển khoản thủ công qua VietQR, sau đó xác nhận bằng mã giao dịch ngân hàng." />
      <PayoutSettingsCard initial={{
        autoEnabled: cfg.get("auto_payout_enabled") === true,
        autoLimit: num(cfg.get("auto_payout_limit_vnd"), 0),
        dailyCap: num(cfg.get("withdraw_daily_cap_vnd"), 0),
      }} />
      <nav className="mb-4 flex gap-2" aria-label="Danh sách">
        <Button asChild variant={history ? "outline" : "default"}><Link href="/admin/withdrawals">Đang chờ</Link></Button>
        <Button asChild variant={history ? "default" : "outline"}><Link href="/admin/withdrawals?tab=history">Lịch sử</Link></Button>
      </nav>
      {list.error ? (
        <ErrorState message="Không tải được danh sách rút tiền. Vui lòng thử lại." />
      ) : history ? (
        <>
          <WithdrawalHistoryTable rows={list.rows} />
          <Pagination total={list.total} page={pg.page} size={pg.size} searchParams={sp} basePath="/admin/withdrawals" />
        </>
      ) : (
        <WithdrawalsTable rows={list.rows} adminId={adminId} />
      )}
    </>
  );
}
