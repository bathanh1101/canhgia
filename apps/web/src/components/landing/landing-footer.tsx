import Link from "next/link";

export function LandingFooter() {
  return (
    <footer className="border-t border-border py-8 text-center text-sm text-text-muted">
      <p>© {new Date().getFullYear()} CanhGia. Hoàn tiền mỗi đơn, so sánh giá thông minh.</p>
      <p className="mt-2">
        <Link href="/chinh-sach-bao-mat" className="underline underline-offset-2 hover:text-text">
          Chính sách bảo mật
        </Link>
      </p>
    </footer>
  );
}
