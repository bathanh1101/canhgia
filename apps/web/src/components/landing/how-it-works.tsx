import { formatVnd } from "@/lib/format";

export function HowItWorks({ minWithdrawVnd }: { minWithdrawVnd?: number | null }) {
  const withdraw = minWithdrawVnd ? `Rút về ngân hàng từ ${formatVnd(minWithdrawVnd)}.` : "Rút về ngân hàng khi đủ hạn mức tối thiểu.";
  const steps = [
    { n: "01", icon: "🔗", tone: "bg-primary-tint-strong", title: "Tìm hoặc dán link", body: "Tìm sản phẩm trong app, hoặc sao chép link từ Shopee, Lazada… CanhGia tự nhận diện và so sánh giá giữa các sàn." },
    { n: "02", icon: "🛒", tone: "bg-info-tint", title: "Mua qua link hoàn tiền", body: "Chọn nơi có giá thực trả thấp nhất, bấm mua. Bạn đặt hàng như bình thường ngay trên app của sàn." },
    { n: "03", icon: "💰", tone: "bg-warning-tint", title: "Nhận tiền về ví", body: `Tiền hoàn được ghi nhận sau vài phút, chuyển sang khả dụng khi đơn hoàn tất. ${withdraw}` },
  ];
  return (
    <section id="cach-hoat-dong" className="bg-bg py-24">
      <div className="mx-auto max-w-[1200px] px-6">
        <div className="text-center">
          <p className="text-xs font-semibold tracking-wide text-primary">CÁCH HOẠT ĐỘNG</p>
          <h2 className="mt-2 text-4xl font-extrabold text-text">Nhận hoàn tiền chỉ với 3 bước</h2>
          <p className="mt-3 text-base text-text-muted">
            Không cần mã giảm giá, không cần đổi nơi mua. Chỉ cần đi qua CanhGia trước khi đặt hàng.
          </p>
        </div>
        <ol className="mt-14 grid gap-6 md:grid-cols-3">
          {steps.map((s) => (
            <li key={s.n} className="rounded-3xl bg-surface p-8 shadow-sm">
              <div className="flex items-start justify-between">
                <span aria-hidden className={`flex size-12 items-center justify-center rounded-xl text-xl ${s.tone}`}>{s.icon}</span>
                <span aria-hidden className="text-4xl font-extrabold text-border">{s.n}</span>
              </div>
              <h3 className="mt-6 text-xl font-bold text-text">{s.title}</h3>
              <p className="mt-3 text-sm leading-relaxed text-text-muted">{s.body}</p>
            </li>
          ))}
        </ol>
      </div>
    </section>
  );
}
