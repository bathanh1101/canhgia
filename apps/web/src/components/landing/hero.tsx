import { formatBps } from "@/lib/format";
import type { LandingData } from "@/lib/landing/schema";
import { DownloadButtons } from "./download-buttons";
import { HeroMock } from "./hero-mock";
import { HeroStats } from "./hero-stats";

export function Hero({ settings, links }: Pick<LandingData, "settings" | "links">) {
  const merchants = settings?.active_merchants ?? 0;
  const maxRate = settings?.max_rate_bps ?? 0;
  return (
    <section className="bg-gradient-to-b from-primary-tint to-surface">
      <div className="mx-auto grid max-w-[1200px] items-center gap-10 px-6 py-16 lg:grid-cols-2 lg:py-24">
        <div>
          <p className="inline-block rounded-full bg-primary-tint-strong px-3.5 py-1.5 text-xs font-semibold text-primary">
            {merchants > 0 ? `Hoàn tiền + So sánh giá · ${merchants} sàn & đối tác` : "Hoàn tiền + So sánh giá"}
          </p>
          <h1 className="mt-6 text-5xl font-extrabold leading-[1.1] text-text lg:text-[56px]">
            Mua sắm thông minh.<br />Hoàn tiền mỗi đơn.
          </h1>
          <p className="mt-6 max-w-[600px] text-lg leading-relaxed text-text-muted">
            CanhGia giúp bạn tìm nơi bán rẻ nhất trên Shopee, Lazada, TikTok Shop, Tiki… và hoàn lại{" "}
            {maxRate > 0 ? `đến ${formatBps(maxRate)} ` : ""}giá trị đơn hàng về tài khoản ngân hàng.
            Miễn phí, không cần thay đổi thói quen mua sắm.
          </p>
          <div className="mt-8"><DownloadButtons links={links} /></div>
          <HeroStats stats={settings?.landing_stats} />
        </div>
        <HeroMock />
      </div>
    </section>
  );
}
