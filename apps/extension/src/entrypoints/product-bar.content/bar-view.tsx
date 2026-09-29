import { useEffect, useState } from 'react'
import type { BarView } from '../../lib/bar-rules'
import { formatHms, formatRate, formatVnd } from '../../lib/format'

export interface BarProps {
  view: BarView
  merchantName: string
  rateBps: number
  cashbackVnd: number | null
  productPage: boolean
  cheaperName: string | null
  busy: boolean
  error: string | null
  onActivate: () => void
  onCompare: () => void
  onClose: () => void
}

function Countdown({ to }: { to: number }) {
  const [now, setNow] = useState(Date.now())
  useEffect(() => {
    const t = setInterval(() => setNow(Date.now()), 1000)
    return () => clearInterval(t)
  }, [])
  return <span className="chip">Còn {formatHms(to - now)}</span>
}

export function BarViewUi(p: BarProps) {
  const { view } = p
  const cheaper = 'cheaper' in view && view.cheaper && p.cheaperName
    ? <button className="chip" onClick={p.onCompare}>Rẻ hơn {formatVnd(view.cheaper.savingVnd)} tại {p.cheaperName} ›</button>
    : null
  const rate = p.cashbackVnd
    ? <>Hoàn tiền <b>{formatRate(p.rateBps)}</b> · khoảng <b>{formatVnd(p.cashbackVnd)}</b> cho sản phẩm này</>
    : p.productPage
      ? <>Hoàn tiền <b>đến {formatRate(p.rateBps)}</b> cho sản phẩm này</>
      : <>Hoàn tiền <b>đến {formatRate(p.rateBps)}</b> trên {p.merchantName} · nhãn hoàn tiền hiện trên từng sản phẩm</>
  const activate = <button className="cg-btn" onClick={p.onActivate} disabled={p.busy}>Kích hoạt hoàn tiền</button>
  const cls = view.kind === 'active' ? 'bar active' : view.kind === 'fake_discount' ? 'bar warn' : view.kind === 'not_eligible' ? 'bar info' : 'bar'

  return (
    <div className={cls} role="region" aria-label="CanhGia">
      <span className="cg-logo"><i>₫</i>CanhGia</span>
      <span className="msg">
        {view.kind === 'inactive' && rate}
        {view.kind === 'active' && <>✓ Đã kích hoạt hoàn tiền <b>{formatRate(p.rateBps)}</b> · Mua như bình thường, đơn sẽ tự ghi nhận vào ví</>}
        {view.kind === 'fake_discount' && <>! Giá hiện tại (mức giảm "-{view.fake.discountPct}%") không thấp hơn mức trung vị 90 ngày ({formatVnd(view.fake.medianVnd)}) · mức giảm có thể không thật</>}
        {view.kind === 'not_eligible' && <>Shop này không tham gia hoàn tiền{view.alternatives > 0 && <> · {view.alternatives} shop khác được hoàn đến {formatRate(view.maxRateBps)}</>}</>}
        {p.error && <span className="cg-err" style={{ marginLeft: 8 }}>{p.error}</span>}
      </span>
      {cheaper}
      {view.kind === 'fake_discount' && <button className="chip" onClick={p.onCompare}>Xem lịch sử giá ›</button>}
      {view.kind === 'not_eligible' && view.alternatives > 0 && <button className="chip" onClick={p.onCompare}>Xem shop khác ›</button>}
      {(view.kind === 'inactive' || view.kind === 'fake_discount') && activate}
      {view.kind === 'active' && <Countdown to={view.expiresAt} />}
      <button className="x" onClick={p.onClose} aria-label="Đóng">✕</button>
    </div>
  )
}
