"use client";

import { ConfirmDialog } from "@/components/admin-kit/confirm-dialog";
import { StatusBadge } from "@/components/admin-kit/status-badge";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { ReasonDialog } from "@/components/admin/withdrawals/reason-dialog";
import { reviewKyc } from "@/app/admin/users/actions";
import { reasonSchema } from "@/app/admin/users/schemas";
import { formatDateTime } from "@/lib/format";

export interface KycView {
  status: string; fullName: string; last4: string; submittedAt: string; rejectReason: string | null;
  frontUrl: string | null; backUrl: string | null;
}

function Img({ src, alt }: { src: string | null; alt: string }) {
  if (!src) return <div className="flex h-40 items-center justify-center rounded-lg bg-bg text-sm text-text-muted">Không tải được ảnh</div>;
  // eslint-disable-next-line @next/next/no-img-element -- 60s signed URL, must not be cached or optimised
  return <img src={src} alt={alt} className="max-h-72 rounded-lg border border-border" />;
}

/** Images come from 60s signed URLs created server-side per page load. */
export function KycReviewPanel({ userId, kyc }: { userId: string; kyc: KycView | null }) {
  if (!kyc) return <Card className="p-4 text-sm text-text-muted">Chưa nộp KYC.</Card>;
  return (
    <Card className="p-4">
      <div className="mb-3 flex flex-wrap items-center gap-3">
        <h3 className="font-semibold">KYC</h3><StatusBadge status={kyc.status} />
        <span className="text-sm text-text-2">{kyc.fullName} · CCCD ***{kyc.last4} · nộp {formatDateTime(kyc.submittedAt)}</span>
      </div>
      {kyc.rejectReason && <p className="mb-3 text-sm text-danger">Lý do từ chối: {kyc.rejectReason}</p>}
      <div className="grid gap-3 md:grid-cols-2">
        <Img src={kyc.frontUrl} alt="CCCD mặt trước" /><Img src={kyc.backUrl} alt="CCCD mặt sau" />
      </div>
      {kyc.status === "pending" && (
        <div className="mt-4 flex gap-2">
          <ConfirmDialog trigger={<Button>Duyệt</Button>} title="Duyệt KYC" description="Xác nhận ảnh và thông tin khớp nhau." confirmLabel="Duyệt" onConfirm={() => reviewKyc(userId, "verified", "")} />
          <ReasonDialog
            trigger={<Button variant="destructive">Từ chối</Button>} title="Từ chối KYC" label="Lý do (5-500 ký tự)" schema={reasonSchema}
            destructive confirmLabel="Từ chối" onSubmit={(reason) => reviewKyc(userId, "rejected", reason)}
          />
        </div>
      )}
    </Card>
  );
}
