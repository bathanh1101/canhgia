import type { Metadata } from "next";
import { contactLine } from "./contact-line";

export const metadata: Metadata = {
  title: "Chính sách bảo mật - CanhGia",
  description: "CanhGia thu thập, sử dụng và bảo vệ dữ liệu cá nhân của bạn như thế nào.",
};

const UPDATED = "30/09/2026";

const DATA: [string, string][] = [
  ["Email và tên hiển thị", "Đăng nhập bằng Google hoặc mã OTP qua email; gửi thông báo và hỗ trợ."],
  ["Mã thiết bị (đã băm), hệ điều hành, kiểu máy, token thông báo đẩy", "Chống gian lận nhiều tài khoản, gửi thông báo đơn hàng và ví."],
  ["Lịch sử nhấp liên kết, đơn hàng ghi nhận từ đối tác, số dư ví, lịch sử rút tiền", "Tính và chi trả hoàn tiền."],
  ["Họ tên, 4 số cuối và mã băm số CCCD, ảnh CCCD hai mặt", "Xác minh danh tính (KYC) trước khi rút tiền."],
  ["Ngân hàng, số tài khoản, tên chủ tài khoản", "Chuyển khoản hoàn tiền; tên chủ tài khoản phải khớp họ tên KYC."],
  ["Nội dung khiếu nại đơn thiếu và ảnh đính kèm", "Xử lý khiếu nại."],
];

const THIRD_PARTIES: [string, string][] = [
  ["AccessTrade", "đối tác tiếp thị liên kết: nhận mã theo dõi lượt nhấp (không kèm email hay họ tên) và trả về đơn hàng, hoa hồng."],
  ["Supabase", "lưu trữ cơ sở dữ liệu, tệp ảnh và xác thực người dùng."],
  ["Firebase (Google)", "gửi thông báo đẩy tới ứng dụng; Google cung cấp đăng nhập bằng tài khoản Google."],
  ["Cloudflare", "Turnstile chống bot khi đăng nhập; phân phối trang web."],
];

const RIGHTS = [
  "Xem và chỉnh sửa tên hiển thị, tùy chọn thông báo ngay trong ứng dụng.",
  "Yêu cầu truy cập, chỉnh sửa, xóa dữ liệu cá nhân hoặc rút lại đồng ý (Nghị định 13/2023/NĐ-CP).",
  "Tắt thông báo đẩy trong ứng dụng hoặc cài đặt thiết bị.",
];

export default function PrivacyPolicyPage() {
  const contact = contactLine();
  return (
    <main className="mx-auto max-w-3xl px-4 py-10 text-text">
      <h1 className="text-3xl font-bold">Chính sách bảo mật</h1>
      <p className="mt-2 text-sm text-text-muted">Cập nhật lần cuối: {UPDATED}</p>
      <p className="mt-6">
        Chính sách này áp dụng cho ứng dụng di động, tiện ích trình duyệt và website CanhGia. Bằng việc sử dụng dịch vụ, bạn đồng ý với nội dung dưới đây.
      </p>

      <h2 className="mt-8 text-xl font-semibold">1. Dữ liệu chúng tôi thu thập và mục đích</h2>
      <ul className="mt-3 list-disc space-y-2 pl-6">
        {DATA.map(([what, why]) => (
          <li key={what}>
            <strong>{what}.</strong> {why}
          </li>
        ))}
      </ul>
      <p className="mt-3">
        Tiện ích trình duyệt chỉ chạy trên Shopee, Lazada, Tiki, TikTok Shop để hiển thị thanh hoàn tiền và đọc giá sản phẩm trên trang đang xem. Tiện ích không đọc lịch sử duyệt web và không gửi nội dung trang khác về máy chủ.
      </p>

      <h2 className="mt-8 text-xl font-semibold">2. Thời gian lưu trữ</h2>
      <ul className="mt-3 list-disc space-y-2 pl-6">
        <li>Dữ liệu tài khoản, ví, đơn hàng, KYC và tài khoản ngân hàng được lưu trong thời gian tài khoản còn hoạt động và thêm thời hạn pháp luật yêu cầu về kế toán, chống gian lận.</li>
        <li>Lịch sử giá sản phẩm giữ tối đa 400 ngày; nhật ký lỗi đồng bộ giữ 90 ngày; mã đăng nhập tiện ích hết hạn sau vài phút và bị xóa.</li>
      </ul>

      <h2 className="mt-8 text-xl font-semibold">3. Bên thứ ba nhận hoặc xử lý dữ liệu</h2>
      <ul className="mt-3 list-disc space-y-2 pl-6">
        {THIRD_PARTIES.map(([name, what]) => (
          <li key={name}>
            <strong>{name}</strong>: {what}
          </li>
        ))}
      </ul>
      <p className="mt-3">Chúng tôi không bán dữ liệu cá nhân và không dùng dữ liệu cho quảng cáo của bên thứ ba.</p>

      <h2 className="mt-8 text-xl font-semibold">4. Bảo mật</h2>
      <p className="mt-3">
        Dữ liệu truyền qua HTTPS. Ảnh CCCD nằm trong kho lưu trữ riêng tư, chỉ chủ tài khoản và quản trị viên đã xác thực hai lớp truy cập; số CCCD chỉ lưu 4 số cuối và mã băm. Rút tiền yêu cầu mã PIN riêng.
      </p>

      <h2 className="mt-8 text-xl font-semibold">5. Quyền của bạn</h2>
      <ul className="mt-3 list-disc space-y-2 pl-6">
        {RIGHTS.map((r) => (
          <li key={r}>{r}</li>
        ))}
      </ul>

      <h2 className="mt-8 text-xl font-semibold">6. Liên hệ</h2>
      <p className="mt-3" data-testid="contact">
        {contact ? (
          <>
            Mọi yêu cầu về dữ liệu cá nhân, gửi tới <a className="text-primary underline" href={`mailto:${contact}`}>{contact}</a>.
          </>
        ) : (
          "Mọi yêu cầu về dữ liệu cá nhân, vui lòng liên hệ qua mục Hỗ trợ trong ứng dụng."
        )}
      </p>
    </main>
  );
}
