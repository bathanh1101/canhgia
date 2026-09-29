import { useEffect, useState } from 'react'
import { LoginPanel } from '../../components/login-panel'
import { send } from '../../lib/messages'

const card = { background: '#fff', border: '1px solid var(--color-border)', borderRadius: 16, padding: 20 } as const
const STEPS = [
  ['Ghim tiện ích', 'Bấm biểu tượng Tiện ích trên thanh công cụ Chrome, rồi ghim CanhGia để luôn thấy mức hoàn tiền.'],
  ['Đăng nhập tài khoản', 'Dùng tài khoản CanhGia trên điện thoại để tiền hoàn từ máy tính về chung một ví.'],
  ['Mua sắm như bình thường', 'Vào Shopee, Lazada… thanh CanhGia sẽ hiện. Bấm Kích hoạt trước khi đặt hàng là xong.'],
] as const

export function App() {
  const [loggedIn, setLoggedIn] = useState(false)
  const check = () => send('popupData', { tabUrl: '' }).then((d) => setLoggedIn(d.loggedIn)).catch(() => setLoggedIn(false))
  useEffect(() => void check(), [])

  return (
    <main style={{ maxWidth: 760, margin: '0 auto', padding: '48px 20px', display: 'grid', gap: 16 }}>
      <span className="cg-logo"><i>₫</i>CanhGia</span>
      <h1 style={{ margin: 0 }}>Cài đặt thành công!</h1>
      <p className="cg-muted" style={{ fontSize: 16 }}>Chỉ còn 3 bước để nhận hoàn tiền khi mua sắm trên máy tính</p>
      {STEPS.map(([title, body], i) => (
        <section key={title} style={card}>
          <h3 style={{ margin: 0 }}>{i + 1}. {title}</h3>
          <p className="cg-muted">{body}</p>
          {i === 1 && (loggedIn ? <b style={{ color: 'var(--color-primary)' }}>✓ Đã đăng nhập</b> : <LoginPanel onDone={() => void check()} />)}
          {i === 2 && <a className="cg-btn" style={{ display: 'inline-block', textDecoration: 'none' }} href="https://shopee.vn" target="_blank" rel="noreferrer">Mở Shopee thử ngay</a>}
        </section>
      ))}
      <p className="cg-muted">Hoạt động trên Shopee, Lazada, Tiki, TikTok Shop; Agoda, Traveloka, Klook kích hoạt từ biểu tượng tiện ích.</p>
      <p className="cg-muted">Quyền riêng tư: CanhGia chỉ hoạt động trên trang của các sàn và đối tác được hỗ trợ. Tiện ích không đọc mật khẩu, thông tin thanh toán hay lịch sử duyệt web khác của bạn.</p>
    </main>
  )
}
