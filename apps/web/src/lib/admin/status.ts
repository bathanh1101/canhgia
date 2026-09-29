import type { BadgeTone } from "@/components/ui/badge";

export interface StatusView {
  label: string;
  tone: BadgeTone;
}

// Keys are DB enum / text values across orders, withdrawals, KYC, flags, complaints.
const STATUS: Record<string, StatusView> = {
  none: { label: "Chưa ghi nhận", tone: "neutral" },
  pending: { label: "Chờ xử lý", tone: "warning" },
  reviewing: { label: "Đang xem xét", tone: "info" },
  processing: { label: "Đang xử lý", tone: "info" },
  credited: { label: "Đã cộng tiền", tone: "success" },
  approved: { label: "Đã duyệt", tone: "success" },
  paid: { label: "Đã thanh toán", tone: "success" },
  verified: { label: "Đã xác minh", tone: "success" },
  actioned: { label: "Đã xử lý", tone: "success" },
  cancelled: { label: "Đã hủy", tone: "danger" },
  reversed: { label: "Đã hoàn lại", tone: "danger" },
  rejected: { label: "Từ chối", tone: "danger" },
  open: { label: "Đang mở", tone: "warning" },
  dismissed: { label: "Bỏ qua", tone: "neutral" },
};

export function statusView(status: string | null | undefined): StatusView {
  if (!status) return { label: "-", tone: "neutral" };
  return Object.hasOwn(STATUS, status) ? STATUS[status] : { label: status, tone: "neutral" };
}
