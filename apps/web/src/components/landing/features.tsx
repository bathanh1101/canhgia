import { formatBps } from "@/lib/format";
import type { PublicSettings } from "@/lib/landing/schema";

export function Features({ settings }: { settings: PublicSettings | null }) {
  const maxRate = settings?.max_rate_bps ?? 0;
  const merchants = settings?.active_merchants ?? 0;
  const items = [
    {
      icon: "💰", tone: "bg-primary-tint-strong",
      title: maxRate > 0 ? `Hoàn tiền đến ${formatBps(maxRate)}` : "Hoàn tiền mỗi đơn",
      body: `Nhận lại tiền thật cho mỗi đơn hàng tại ${merchants > 0 ? `${merchants} ` : ""}sàn và đối tác. Hạng VIP càng cao, tỷ lệ càng lớn.`,
    },
    { icon: "🛒", tone: "bg-info-tint", title: "So sánh giá 4 sàn", body: "Gộp cùng một sản phẩm trên nhiều sàn, tính sẵn giá thực trả sau voucher và hoàn tiền." },
    { icon: "🔔", tone: "bg-warning-tint", title: "Lịch sử & cảnh báo giá", body: "Xem biến động giá 1 năm, đặt mức giá mong muốn và nhận thông báo khi giá chạm mục tiêu." },
    { icon: "!", tone: "bg-danger-tint text-danger", title: "Phát hiện giảm giá ảo", body: "Cảnh báo khi shop tăng giá trước sale rồi \"giảm sâu\", giúp bạn không mua hớ dịp 11.11." },
    { icon: "₫", tone: "bg-primary-tint-strong text-primary", title: "Tiện ích Chrome", body: "Tự hiện mức hoàn tiền và nơi bán rẻ hơn ngay khi bạn lướt Shopee, Lazada trên máy tính.", id: "tien-ich-chrome" },
    { icon: "⚡", tone: "bg-info-tint", title: "Rút tiền trong 1 ngày làm việc", body: "Rút về tài khoản ngân hàng chính chủ qua VietQR, bảo vệ bằng mã PIN và FaceID." },
  ];
  return (
    <section id="tinh-nang" className="py-24">
      <div className="mx-auto max-w-[1200px] px-6">
        <div className="text-center">
          <p className="text-xs font-semibold tracking-wide text-primary">TÍNH NĂNG</p>
          <h2 className="mt-2 text-4xl font-extrabold text-text">Mọi công cụ để mua đúng giá, đúng lúc</h2>
        </div>
        <ul className="mt-14 grid gap-6 md:grid-cols-2 lg:grid-cols-3">
          {items.map((f) => (
            <li id={f.id} key={f.title} className="rounded-3xl border border-border p-7">
              <span aria-hidden className={`flex size-12 items-center justify-center rounded-xl text-xl font-bold ${f.tone}`}>{f.icon}</span>
              <h3 className="mt-5 text-lg font-bold text-text">{f.title}</h3>
              <p className="mt-2 text-sm leading-relaxed text-text-muted">{f.body}</p>
            </li>
          ))}
        </ul>
      </div>
    </section>
  );
}
