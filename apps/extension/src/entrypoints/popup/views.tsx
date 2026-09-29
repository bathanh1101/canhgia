import { useEffect, useState } from 'react'
import { canInject, pageKind } from '../../lib/merchant-page-detectors'
import { formatHm, formatRate, formatVnd } from '../../lib/format'
import { RequestError, send } from '../../lib/messages'
import type { MerchantRate, PopupUser, RecentOrder } from '../../lib/types'

const VIP: Record<string, string> = { dong: 'Đồng', bac: 'Bạc', vang: 'Vàng', kim_cuong: 'Kim Cương' }
const ORDER_STATE: Record<string, string> = { pending: 'Đã ghi nhận', credited: 'Đã duyệt', cancelled: 'Đã hủy', reversed: 'Đã hoàn lại', none: 'Đã ghi nhận' }
const card = { background: '#fff', border: '1px solid var(--color-border)', borderRadius: 14, padding: 14 } as const

export function AccountHeader({ user, onSignOut }: { user: PopupUser; onSignOut: () => void }) {
  return (
    <div style={card}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <span className="cg-logo"><i>₫</i>CanhGia</span>
        <button className="cg-link" onClick={onSignOut}>Đăng xuất</button>
      </div>
      <p style={{ margin: '8px 0 0' }}><b>{user.name}</b>{user.vipCode && <span className="cg-muted"> · ★ Hạng {VIP[user.vipCode] ?? user.vipCode}</span>}</p>
      <div style={{ display: 'flex', gap: 24, marginTop: 8 }}>
        <div><div className="cg-muted">Khả dụng</div><b>{formatVnd(user.availableVnd)}</b></div>
        <div><div className="cg-muted">Chờ duyệt</div><b>{formatVnd(user.pendingVnd)}</b></div>
      </div>
    </div>
  )
}

export function IdleView() {
  return <div style={card}><b>Chưa ở trang sàn được hỗ trợ</b><p className="cg-muted">Mở Shopee, Lazada, Tiki, TikTok Shop, Agoda, Traveloka hoặc Klook để kích hoạt hoàn tiền.</p></div>
}

export function NotActivatedView({ merchant, tabId, tabUrl }: { merchant: MerchantRate; tabId: number; tabUrl: string }) {
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  // only a real product page carries its URL into the link; elsewhere activation uses the campaign link
  const url = canInject(merchant) && pageKind(merchant.merchant_id, tabUrl) === 'product' ? tabUrl : undefined
  const go = async () => {
    setBusy(true)
    setError(null)
    try {
      await send('activate', { tabId, merchantId: merchant.merchant_id, url })
      window.close()
    } catch (e) {
      setError(e instanceof RequestError && e.message === 'rate_limited' ? 'Bạn thao tác quá nhanh, thử lại sau ít phút.' : 'Chưa kích hoạt được. Vui lòng thử lại.')
      setBusy(false)
    }
  }
  return (
    <div style={{ ...card, display: 'grid', gap: 8 }}>
      <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
        <span className="badge">{merchant.badge_letter}</span>
        <div><b>Đang ở {merchant.name}</b><div className="cg-muted">Hoàn tiền đến {formatRate(merchant.max_user_rate_bps)} · chưa kích hoạt</div></div>
      </div>
      {error && <p className="cg-err">{error}</p>}
      <button className="cg-btn" onClick={go} disabled={busy}>Kích hoạt hoàn tiền</button>
      <p className="cg-muted" style={{ margin: 0 }}>Hiệu lực {merchant.activation_hours} giờ cho mọi đơn trên {merchant.name}</p>
    </div>
  )
}

export function ActivatedView({ merchant, expiresAt, onExpire }: { merchant: MerchantRate; expiresAt: number; onExpire: () => void }) {
  const [left, setLeft] = useState(expiresAt - Date.now())
  useEffect(() => {
    const t = setInterval(() => {
      const l = expiresAt - Date.now()
      setLeft(l)
      if (l <= 0) onExpire()
    }, 15000)
    return () => clearInterval(t)
  }, [expiresAt, onExpire])
  return (
    <div style={{ ...card, background: 'var(--color-primary-tint)' }}>
      <b>✓ Đã kích hoạt trên {merchant.name}</b>
      <div className="cg-muted">Còn hiệu lực {formatHm(left)}</div>
      <p style={{ margin: '6px 0 0' }}>Mua hàng như bình thường, đơn sẽ tự ghi nhận vào ví CanhGia trong vài phút.</p>
    </div>
  )
}

export function RecentOrders({ orders }: { orders: RecentOrder[] }) {
  if (!orders.length) return null
  return (
    <div style={card}>
      <b>Đơn gần đây</b>
      {orders.map((o, i) => (
        <div className="row" key={i}>
          <div className="grow"><div>{o.product_name ?? o.merchant_id}</div><div className="cg-muted">{ORDER_STATE[o.credit_state] ?? o.credit_state}</div></div>
          <b style={{ color: 'var(--color-primary)' }}>+{formatVnd(o.user_cashback_vnd)}</b>
        </div>
      ))}
    </div>
  )
}
