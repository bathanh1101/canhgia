import type { LandingLinks } from "@/lib/landing/schema";
import { DownloadButtons } from "./download-buttons";

export function DownloadCta({ links }: { links: LandingLinks }) {
  if (!links.appstore && !links.play && !links.cws) return null;
  return (
    <section id="tai-ung-dung" className="bg-primary-tint py-20">
      <div className="mx-auto flex max-w-[1200px] flex-col items-center gap-6 px-6 text-center">
        <h2 className="text-3xl font-extrabold text-text">Bắt đầu nhận hoàn tiền hôm nay</h2>
        <p className="max-w-xl text-text-muted">Tải ứng dụng CanhGia hoặc thêm tiện ích Chrome để thấy mức hoàn tiền ngay khi mua sắm.</p>
        <DownloadButtons links={links} />
      </div>
    </section>
  );
}
