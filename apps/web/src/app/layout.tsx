import type { Metadata } from "next";
import { Inter } from "next/font/google";
import "./globals.css";

const inter = Inter({ subsets: ["latin", "vietnamese"], variable: "--font-inter" });

export const metadata: Metadata = {
  title: "CanhGia - Hoàn tiền mỗi đơn, so sánh giá thông minh",
  description:
    "CanhGia giúp bạn tìm nơi bán rẻ nhất trên Shopee, Lazada, TikTok Shop, Tiki... và nhận hoàn tiền về tài khoản ngân hàng.",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="vi" className={inter.variable}>
      <body className="antialiased">{children}</body>
    </html>
  );
}
