import type { ReactNode } from "react";
import { DataTable, type Column } from "@/components/admin-kit/data-table";
import { StatusBadge } from "@/components/admin-kit/status-badge";
import { Badge } from "@/components/ui/badge";
import { Card } from "@/components/ui/card";
import { maskAccount } from "@/components/admin/withdrawals/withdrawal-state";
import { formatDateTime, formatVnd } from "@/lib/format";
import { FlagActions } from "./flag-actions";
import { flagLabel } from "./flag-labels";

export interface ProfileData {
  profile: { id: string; email: string | null; display_name: string | null; created_at: string; locked_at: string | null; vip_tier_code: string | null; referral_code: string };
  risk: { risk_score: number; level: string; lock_reason: string | null } | null;
  wallet: { available_vnd: number; pending_vnd: number; held_vnd: number; total_earned_vnd: number } | null;
  ledger: { id: number; entry_type: string; amount_vnd: number; note: string | null; created_at: string }[];
  orders: { id: string; transaction_id: string | null; merchant_id: string; value_vnd: number; user_cashback_vnd: number; credit_state: string; order_time: string | null }[];
  clicks: { id: number; merchant_id: string; source: string; status: string; created_at: string }[];
  devices: { id: number; platform: string; model: string | null; last_seen_at: string }[];
  banks: { id: string; bank_bin: string; account_number: string; account_name: string; holder_name_verified: boolean }[];
  referrals: { id: number; referee_id: string; status: string; bonus_vnd: number; created_at: string }[];
  flags: { id: number; type: string; status: string; score: number; created_at: string }[];
}

const Section = ({ title, children }: { title: string; children: ReactNode }) => (
  <section className="mb-6"><h2 className="mb-2 text-lg font-semibold text-text">{title}</h2>{children}</section>
);

function Table<T>({ rows, columns, rowKey, empty }: { rows: T[]; columns: Column<T>[]; rowKey: (r: T) => string | number; empty: string }) {
  return <DataTable rows={rows} columns={columns} rowKey={rowKey} emptyTitle={empty} />;
}

export function UserProfileSections({ d }: { d: ProfileData }) {
  const locked = d.profile.locked_at !== null;
  const stat = (k: string, v: string) => (<div key={k}><div className="text-xs text-text-muted">{k}</div><div className="font-semibold">{v}</div></div>);
  return (
    <>
      <Card className="mb-6 grid gap-4 p-4 md:grid-cols-4">
        {stat("Email", d.profile.email ?? "-")}
        {stat("Tên hiển thị", d.profile.display_name ?? "-")}
        {stat("Hạng VIP", d.profile.vip_tier_code ?? "-")}
        {stat("Ngày tạo", formatDateTime(d.profile.created_at))}
        {stat("Mã giới thiệu", d.profile.referral_code)}
        {stat("Điểm rủi ro", d.risk ? `${d.risk.risk_score} (${d.risk.level})` : "0")}
        {stat("Khả dụng", formatVnd(d.wallet?.available_vnd ?? 0))}
        {stat("Chờ / giữ", `${formatVnd(d.wallet?.pending_vnd ?? 0)} / ${formatVnd(d.wallet?.held_vnd ?? 0)}`)}
        {locked && <div className="md:col-span-4"><Badge tone="danger">Đã khóa</Badge> <span className="text-sm">{d.risk?.lock_reason}</span></div>}
      </Card>

      <Section title="Cảnh báo">
        <Table rows={d.flags} rowKey={(f) => f.id} empty="Không có cảnh báo" columns={[
          { key: "t", header: "Loại", cell: (f) => flagLabel(f.type) },
          { key: "s", header: "Trạng thái", cell: (f) => <StatusBadge status={f.status} /> },
          { key: "sc", header: "Điểm", cell: (f) => f.score },
          { key: "d", header: "Thời gian", cell: (f) => formatDateTime(f.created_at) },
          { key: "a", header: "", cell: (f) => f.status === "open" ? <FlagActions flagId={f.id} userId={d.profile.id} type={f.type} locked={locked} /> : null },
        ]} />
      </Section>
      <Section title="Sổ cái (50 gần nhất)">
        <Table rows={d.ledger} rowKey={(l) => l.id} empty="Chưa có giao dịch" columns={[
          { key: "t", header: "Loại", cell: (l) => l.entry_type },
          { key: "a", header: "Số tiền", cell: (l) => formatVnd(l.amount_vnd) },
          { key: "n", header: "Ghi chú", cell: (l) => l.note ?? "-" },
          { key: "d", header: "Thời gian", cell: (l) => formatDateTime(l.created_at) },
        ]} />
      </Section>
      <Section title="Đơn hàng">
        <Table rows={d.orders} rowKey={(o) => o.id} empty="Chưa có đơn hàng" columns={[
          { key: "c", header: "Mã đơn", cell: (o) => o.transaction_id ?? "-" },
          { key: "m", header: "Sàn", cell: (o) => o.merchant_id },
          { key: "v", header: "Giá trị", cell: (o) => formatVnd(o.value_vnd) },
          { key: "b", header: "Hoàn tiền", cell: (o) => formatVnd(o.user_cashback_vnd) },
          { key: "s", header: "Trạng thái", cell: (o) => <StatusBadge status={o.credit_state} /> },
          { key: "d", header: "Thời gian", cell: (o) => formatDateTime(o.order_time) },
        ]} />
      </Section>
      <Section title="Lượt click (50 gần nhất)">
        <Table rows={d.clicks} rowKey={(c) => c.id} empty="Chưa có click" columns={[
          { key: "m", header: "Sàn", cell: (c) => c.merchant_id },
          { key: "s", header: "Nguồn", cell: (c) => c.source },
          { key: "st", header: "Trạng thái", cell: (c) => c.status },
          { key: "d", header: "Thời gian", cell: (c) => formatDateTime(c.created_at) },
        ]} />
      </Section>
      <Section title="Thiết bị">
        <Table rows={d.devices} rowKey={(x) => x.id} empty="Chưa có thiết bị" columns={[
          { key: "p", header: "Nền tảng", cell: (x) => x.platform }, { key: "m", header: "Model", cell: (x) => x.model ?? "-" },
          { key: "d", header: "Lần cuối", cell: (x) => formatDateTime(x.last_seen_at) },
        ]} />
      </Section>
      <Section title="Tài khoản ngân hàng">
        <Table rows={d.banks} rowKey={(b) => b.id} empty="Chưa liên kết ngân hàng" columns={[
          { key: "b", header: "BIN", cell: (b) => b.bank_bin }, { key: "n", header: "Số TK", cell: (b) => maskAccount(b.account_number) },
          { key: "o", header: "Chủ TK", cell: (b) => b.account_name },
          { key: "v", header: "Xác minh tên", cell: (b) => (b.holder_name_verified ? "Đã xác minh" : "Chưa") },
        ]} />
      </Section>
      <Section title="Giới thiệu">
        <Table rows={d.referrals} rowKey={(r) => r.id} empty="Chưa giới thiệu ai" columns={[
          { key: "r", header: "Người được giới thiệu", cell: (r) => r.referee_id.slice(0, 8) },
          { key: "s", header: "Trạng thái", cell: (r) => r.status }, { key: "b", header: "Thưởng", cell: (r) => formatVnd(r.bonus_vnd) },
          { key: "d", header: "Ngày", cell: (r) => formatDateTime(r.created_at) },
        ]} />
      </Section>
    </>
  );
}
