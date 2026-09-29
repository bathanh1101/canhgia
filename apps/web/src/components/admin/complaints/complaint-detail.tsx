import Link from "next/link";
import { StatusBadge } from "@/components/admin-kit/status-badge";
import { Badge } from "@/components/ui/badge";
import { Card } from "@/components/ui/card";
import { formatDate, formatDateTime, formatVnd } from "@/lib/format";
import { AtLookupPanel } from "./at-lookup-panel";
import { ResolveDialog } from "./resolve-dialog";
import { approvalPhase } from "./complaint-state";

export interface ComplaintDetailData {
  report: {
    id: number; public_code: string; user_id: string; merchant_id: string; order_code: string; order_value_vnd: number; purchased_on: string;
    status: string; admin_note: string | null; created_at: string; first_approved_by: string | null; first_approved_amount: number | null;
    resolution_amount_vnd: number | null;
  };
  email: string; merchantName: string; firstApproverEmail: string | null;
  images: string[];
  sameCodeOrders: { id: string; source: string; transaction_id: string | null; value_vnd: number; user_id: string | null; credit_state: string }[];
  clicks: { id: number; source: string; status: string; created_at: string }[];
}

const Row = ({ k, v }: { k: string; v: string }) => (<div><dt className="text-xs text-text-muted">{k}</dt><dd className="font-medium">{v}</dd></div>);

export function ComplaintDetail({ d, adminId }: { d: ComplaintDetailData; adminId: string }) {
  const r = d.report;
  const phase = approvalPhase(r, adminId);
  const atOrder = d.sameCodeOrders.some((o) => o.source === "accesstrade");
  return (
    <div className="flex flex-col gap-4">
      <Card className="p-4">
        <div className="mb-3 flex flex-wrap items-center gap-2">
          <h2 className="text-lg font-semibold">{r.public_code}</h2><StatusBadge status={r.status} />
          {r.status === "reviewing" && r.first_approved_by && (
            <Badge tone="warning">Chờ admin thứ 2 ({d.firstApproverEmail ?? r.first_approved_by.slice(0, 8)}, {formatVnd(r.first_approved_amount)})</Badge>
          )}
        </div>
        <dl className="grid gap-3 md:grid-cols-3">
          <Row k="Người dùng" v={d.email} /><Row k="Sàn" v={d.merchantName} /><Row k="Mã đơn" v={r.order_code} />
          <Row k="Giá trị đơn" v={formatVnd(r.order_value_vnd)} /><Row k="Ngày mua" v={formatDate(r.purchased_on)} /><Row k="Gửi lúc" v={formatDateTime(r.created_at)} />
          {r.resolution_amount_vnd !== null && <Row k="Đã hoàn" v={formatVnd(r.resolution_amount_vnd)} />}
          {r.admin_note && <Row k="Ghi chú admin" v={r.admin_note} />}
        </dl>
        <div className="mt-4 flex items-center gap-3">
          <ResolveDialog reportId={r.id} maxAmount={r.order_value_vnd} phase={phase} firstAmount={r.first_approved_amount} blockedByOrder={atOrder} />
          <Link href={`/admin/users/${r.user_id}`} className="text-sm text-primary underline">Xem người dùng</Link>
        </div>
      </Card>

      <Card className="p-4">
        <h3 className="mb-2 font-semibold">Ảnh đính kèm</h3>
        {d.images.length === 0 ? <p className="text-sm text-text-muted">Không có ảnh.</p> : (
          <div className="flex flex-wrap gap-3">
            {/* eslint-disable-next-line @next/next/no-img-element -- 60s signed URLs */}
            {d.images.map((src, i) => <img key={src} src={src} alt={`Ảnh khiếu nại ${i + 1}`} className="max-h-72 rounded-lg border border-border" />)}
          </div>
        )}
      </Card>

      <Card className="p-4">
        <h3 className="mb-2 font-semibold">Đơn đã có cùng mã ({d.sameCodeOrders.length})</h3>
        {d.sameCodeOrders.length === 0 ? <p className="text-sm text-text-muted">Chưa có đơn nào trùng mã đã chuẩn hóa.</p> : (
          <ul className="text-sm">
            {d.sameCodeOrders.map((o) => (
              <li key={o.id}>{o.source === "accesstrade" ? "AccessTrade" : "Thủ công"} · {o.transaction_id} · {formatVnd(o.value_vnd)} · <StatusBadge status={o.credit_state} />
                {o.user_id && o.user_id !== r.user_id && <Badge tone="danger" className="ml-1">Người dùng khác</Badge>}</li>
            ))}
          </ul>
        )}
        {atOrder && <p className="mt-2 text-sm text-danger">Đơn AccessTrade đã tồn tại nên không thể duyệt khiếu nại này.</p>}
      </Card>

      <Card className="p-4">
        <h3 className="mb-2 font-semibold">Click của người dùng quanh ngày mua (±3 ngày)</h3>
        {d.clicks.length === 0 ? <p className="text-sm text-text-muted">Không có click.</p> : (
          <ul className="text-sm">{d.clicks.map((c) => <li key={c.id}>#{c.id} · {c.source} · {c.status} · {formatDateTime(c.created_at)}</li>)}</ul>
        )}
      </Card>

      <AtLookupPanel reportId={r.id} reportUserId={r.user_id} />
    </div>
  );
}
