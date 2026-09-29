import Link from "next/link";

const LINKS = [
  { href: "#tinh-nang", label: "Tính năng" },
  { href: "#cach-hoat-dong", label: "Cách hoạt động" },
  { href: "#tinh-nang", label: "So sánh giá" },
  { href: "#tien-ich-chrome", label: "Tiện ích Chrome" },
  { href: "#doi-tac", label: "Đối tác" },
];

export function LandingNav({ showDownload }: { showDownload: boolean }) {
  return (
    <header className="sticky top-0 z-40 border-b border-border bg-surface/95 backdrop-blur">
      <div className="mx-auto flex h-[78px] max-w-[1200px] items-center justify-between gap-6 px-6">
        <Link href="/" className="flex items-center gap-2.5" aria-label="CanhGia">
          <span className="flex size-9 items-center justify-center rounded-[10px] bg-primary font-bold text-white">₫</span>
          <span className="text-lg font-bold text-text">CanhGia</span>
        </Link>
        <nav aria-label="Chính" className="hidden gap-8 text-sm font-medium text-text-2 lg:flex">
          {LINKS.map((l) => (
            <a key={l.label} href={l.href} className="hover:text-primary">{l.label}</a>
          ))}
        </nav>
        {showDownload && (
          <a href="#tai-ung-dung" className="rounded-lg bg-primary px-4 py-2.5 text-sm font-semibold text-white hover:bg-primary-dark">
            Tải ứng dụng
          </a>
        )}
      </div>
    </header>
  );
}
