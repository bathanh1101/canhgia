import { PageHeader } from "@/components/admin-kit/page-header";
import { ErrorState } from "@/components/admin-kit/states";
import { buildRuleRows, maxShareBps } from "@/components/admin/cashback-rules/rules-logic";
import { RulesTable } from "@/components/admin/cashback-rules/rules-table";
import { SettingsEditor } from "@/components/admin/cashback-rules/settings-editor";
import { Simulator } from "@/components/admin/cashback-rules/simulator";
import { VipTiersTable } from "@/components/admin/cashback-rules/vip-tiers-table";
import { requireAdmin } from "@/lib/admin/require-admin";
import type { Json } from "@/lib/supabase/database.types";

export const dynamic = "force-dynamic";

const H2 = ({ children }: { children: React.ReactNode }) => <h2 className="mb-3 mt-8 text-lg font-semibold text-text">{children}</h2>;

export default async function CashbackRulesPage() {
  const { supabase } = await requireAdmin();
  const [merchants, commissions, rules, tiers, settings] = await Promise.all([
    supabase.from("merchants").select("id,name").order("sort"),
    supabase.from("campaign_commissions").select("merchant_id,category_key,commission_rate_bps"),
    supabase.from("cashback_rules").select("merchant_id,category_key,user_share_bps"),
    supabase.from("vip_tiers").select("code,name,min_gmv_12m_vnd,bonus_bps").order("min_gmv_12m_vnd"),
    supabase.from("app_settings").select("key,value"),
  ]);
  if ([merchants, commissions, rules, tiers, settings].some((r) => r.error)) {
    return <ErrorState message="Không tải được cấu hình. Vui lòng thử lại." />;
  }
  const tierList = tiers.data ?? [];
  const values: Record<string, Json> = Object.fromEntries((settings.data ?? []).map((s) => [s.key, s.value]));
  const rows = buildRuleRows(merchants.data ?? [], commissions.data ?? [], rules.data ?? []);

  return (
    <>
      <PageHeader
        title="Cấu hình tỷ lệ hoàn"
        description="Thay đổi chỉ áp dụng cho đơn được ghi nhận sau đó (tỷ lệ được chốt vào từng đơn)."
      />
      <H2>Tỷ lệ hoàn theo sàn và danh mục</H2>
      <RulesTable rows={rows} maxShareBps={maxShareBps(tierList)} />
      <H2>Tính thử</H2>
      <Simulator merchants={merchants.data ?? []} tiers={tierList} />
      <H2>Hạng VIP</H2>
      <VipTiersTable tiers={tierList} />
      <H2>Cấu hình hệ thống</H2>
      <SettingsEditor values={values} />
    </>
  );
}
