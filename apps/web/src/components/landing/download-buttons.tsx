import type { LandingLinks } from "@/lib/landing/schema";

const base = "inline-flex h-14 items-center gap-3 rounded-xl px-4 text-left";

/** Store/extension buttons. A button is hidden when its env link is unset. Returns null when none. */
export function DownloadButtons({ links }: { links: LandingLinks }) {
  if (!links.appstore && !links.play && !links.cws) return null;
  return (
    <div className="flex flex-wrap gap-3">
      {links.appstore && (
        <a href={links.appstore} className={`${base} bg-slate-900 text-white`}>
          <span aria-hidden className="flex size-8 items-center justify-center rounded-lg bg-white/10 font-bold">A</span>
          <span><span className="block text-[10px] opacity-80">Tải về trên</span><span className="text-base font-bold">App Store</span></span>
        </a>
      )}
      {links.play && (
        <a href={links.play} className={`${base} bg-slate-900 text-white`}>
          <span aria-hidden className="flex size-8 items-center justify-center rounded-lg bg-white/10 font-bold">G</span>
          <span><span className="block text-[10px] opacity-80">Tải về trên</span><span className="text-base font-bold">Google Play</span></span>
        </a>
      )}
      {links.cws && (
        <a href={links.cws} className={`${base} border border-primary-tint-strong bg-primary-tint text-text`}>
          <span aria-hidden className="flex size-8 items-center justify-center rounded-lg bg-primary-tint-strong font-bold text-primary">C</span>
          <span><span className="block text-[10px] text-text-muted">Thêm vào</span><span className="text-base font-bold">Chrome</span></span>
        </a>
      )}
    </div>
  );
}
