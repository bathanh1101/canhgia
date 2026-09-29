import type { CompareRow, MerchantRate, PricePoint } from '../../lib/types'
import { formatVnd } from '../../lib/format'

interface Props {
  rows: CompareRow[]
  rates: Record<string, MerchantRate>
  currentOfferId: number | null
  history: PricePoint[]
  onBuy: (row: CompareRow) => void
  onClose: () => void
}

export function ComparePanel({ rows, rates, currentOfferId, history, onBuy, onClose }: Props) {
  const min = history.length ? Math.min(...history.map((h) => h.min_price_vnd)) : null
  const max = history.length ? Math.max(...history.map((h) => h.min_price_vnd)) : null
  return (
    <div className="panel" role="dialog" aria-label="So sánh giá">
      <div style={{ display: 'flex', justifyContent: 'space-between' }}>
        <h4>So sánh giá</h4>
        <button className="x" onClick={onClose} aria-label="Đóng">✕</button>
      </div>
      {rows.map((r) => {
        const m = rates[r.merchant_id]
        const current = r.offer_id === currentOfferId
        return (
          <div className="row" key={r.offer_id}>
            <span className="badge">{m?.badge_letter ?? '?'}</span>
            <div className="grow">
              <div><b>{r.shop_name ?? m?.name ?? r.merchant_id}</b></div>
              <div className="cg-muted">{formatVnd(r.price_vnd)}{r.est_cashback_vnd > 0 && ` · hoàn ${formatVnd(r.est_cashback_vnd)}`}</div>
              <div className="cg-muted">Thực trả {formatVnd(r.effective_price_vnd)}</div>
            </div>
            {current ? <span className="chip">Đang xem</span>
              : r.cashback_eligible && r.url
                ? <button className="cg-btn" onClick={() => onBuy(r)}>Mua</button> : null}
          </div>
        )
      })}
      {min !== null && max !== null && (
        <p className="cg-muted">Lịch sử giá 90 ngày: thấp nhất {formatVnd(min)}, cao nhất {formatVnd(max)}</p>
      )}
    </div>
  )
}
