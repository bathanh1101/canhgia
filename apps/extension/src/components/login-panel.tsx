import { useState } from 'react'
import { send } from '../lib/messages'
import { QrLoginPanel } from './qr-login-panel'

/** Logged-out block shared by the popup (state C) and the welcome page (step 2). */
export function LoginPanel({ onDone }: { onDone: () => void }) {
  const [qr, setQr] = useState(false)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const google = async () => {
    setBusy(true)
    setError(null)
    try {
      await send('signInGoogle', {})
      onDone()
    } catch {
      setError('Đăng nhập Google chưa thành công. Vui lòng thử lại.')
    } finally {
      setBusy(false)
    }
  }

  return (
    <div style={{ display: 'grid', gap: 10 }}>
      {error && <p className="cg-err">{error}</p>}
      <button className="cg-btn" onClick={() => setQr((v) => !v)}>{qr ? 'Ẩn mã QR' : 'Quét mã bằng app CanhGia'}</button>
      {qr && <QrLoginPanel onDone={onDone} />}
      <button className="cg-btn ghost" onClick={google} disabled={busy}>Tiếp tục với Google</button>
      <button className="cg-btn ghost" disabled title="Sắp có">Đăng nhập bằng số điện thoại (sắp có)</button>
    </div>
  )
}
