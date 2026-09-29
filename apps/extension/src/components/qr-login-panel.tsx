import { useEffect, useState } from 'react'
import QRCode from 'qrcode'
import { send } from '../lib/messages'
import { formatHms } from '../lib/format'

const POLL_MS = 2000 // backend contract: poll >= 2 s

export function QrLoginPanel({ onDone }: { onDone: () => void }) {
  const [img, setImg] = useState<string | null>(null)
  const [expiresAt, setExpiresAt] = useState(0)
  const [left, setLeft] = useState(0)
  const [error, setError] = useState<string | null>(null)
  const [round, setRound] = useState(0)
  const [dead, setDead] = useState(false)

  useEffect(() => {
    let stop = false
    let timer: ReturnType<typeof setTimeout> | undefined
    setImg(null)
    setDead(false)
    setError(null)
    const poll = async () => {
      try {
        const r = await send('qrPoll', {})
        if (stop) return
        if (r.state === 'approved') return onDone()
        if (r.state === 'expired') return setDead(true)
        timer = setTimeout(poll, POLL_MS)
      } catch {
        if (!stop) setError('Không kiểm tra được trạng thái đăng nhập. Thử tạo mã mới.')
      }
    }
    send('qrStart', {})
      .then(async (q) => {
        const url = await QRCode.toDataURL(q.payload, { margin: 1, width: 160 })
        if (stop) return
        setImg(url)
        setExpiresAt(q.expiresAt)
        timer = setTimeout(poll, POLL_MS)
      })
      .catch(() => !stop && setError('Không tạo được mã QR. Kiểm tra kết nối rồi thử lại.'))
    return () => {
      stop = true
      clearTimeout(timer)
    }
  }, [round, onDone])

  useEffect(() => {
    const t = setInterval(() => setLeft(Math.max(0, expiresAt - Date.now())), 1000)
    setLeft(Math.max(0, expiresAt - Date.now()))
    return () => clearInterval(t)
  }, [expiresAt])

  const expired = dead || (!!expiresAt && left === 0)
  return (
    <div style={{ textAlign: 'center' }}>
      {error && <p className="cg-err">{error}</p>}
      {img && !expired && <img src={img} width={160} height={160} alt="Mã QR đăng nhập" />}
      {img && !expired && <p className="cg-muted">Mã hết hạn sau {formatHms(left).slice(3)}</p>}
      {(expired || error) && <button className="cg-btn" onClick={() => setRound((n) => n + 1)}>Tạo mã mới</button>}
      {!img && !expired && !error && <p className="cg-muted">Đang tạo mã…</p>}
      <p className="cg-muted">Mở app CanhGia › Tài khoản › Đăng nhập tiện ích Chrome, rồi quét mã.</p>
    </div>
  )
}
