// Decorative product mock. Every figure here is illustrative and labelled "Minh họa".
export function HeroMock() {
  return (
    <div className="relative mx-auto h-[600px] w-[440px] max-w-full" role="img" aria-label="Minh họa giao diện ứng dụng CanhGia">
      <span className="absolute right-0 top-0 z-20 rounded-full bg-slate-900 px-3 py-1 text-xs font-semibold text-white">Minh họa</span>
      <div className="absolute left-0 top-10 h-[540px] w-[240px] rounded-[28px] bg-surface p-4 shadow-2xl ring-1 ring-border">
        <p className="text-center text-sm font-bold text-text">So sánh giá</p>
        <div className="mt-4 rounded-xl bg-primary p-3 text-white">
          <p className="text-[10px] opacity-80">Giá thực trả thấp nhất</p>
          <p className="text-2xl font-bold">5.731.100đ</p>
        </div>
        {["LazMall Sony", "Sony Official Store", "Tiki Trading"].map((n, i) => (
          <div key={n} className={`mt-3 rounded-xl border p-3 text-xs ${i === 0 ? "border-primary bg-primary-tint" : "border-border"}`}>
            <p className="font-semibold text-text">{n}</p>
            <p className="text-text-muted">Voucher và hoàn tiền đã tính</p>
          </div>
        ))}
      </div>
      <div className="absolute right-0 top-4 h-[570px] w-[260px] overflow-hidden rounded-[28px] bg-bg shadow-2xl ring-1 ring-border">
        <div className="bg-primary p-4 pb-16 text-white">
          <p className="text-sm font-bold">Xin chào, Minh</p>
          <p className="mt-1 text-[10px] opacity-90">Tìm sản phẩm, so sánh giá 4 sàn…</p>
        </div>
        <div className="-mt-12 mx-3 rounded-2xl bg-surface p-3 shadow">
          <p className="text-[10px] text-text-muted">Số dư khả dụng</p>
          <p className="text-lg font-bold text-text">1.250.000đ</p>
          <p className="mt-2 text-[10px] text-text-muted">Chờ duyệt</p>
          <p className="text-sm font-bold text-warning">320.000đ</p>
        </div>
        <div className="m-3 rounded-2xl border border-warning bg-warning-tint p-3 text-[11px]">
          <p className="font-semibold text-text">Phát hiện link Shopee vừa sao chép</p>
          <p className="mt-1 text-text-muted">Tạo link hoàn tiền cho sản phẩm này?</p>
          <p className="mt-2 rounded-lg bg-primary py-1.5 text-center font-semibold text-white">Tạo link hoàn tiền</p>
        </div>
      </div>
      <div className="absolute bottom-24 left-[-8px] z-10 rounded-2xl bg-surface p-3 shadow-xl">
        <p className="text-sm font-bold text-text">+454.300đ</p>
        <p className="text-[10px] text-text-muted">Tiền hoàn đã về ví</p>
      </div>
      <div className="absolute bottom-10 right-[-8px] z-10 rounded-2xl bg-surface p-3 shadow-xl">
        <p className="text-sm font-bold text-text">Rẻ hơn 104.600đ</p>
        <p className="text-[10px] text-text-muted">Tìm thấy tại Lazada</p>
      </div>
    </div>
  );
}
