import { useCallback, useEffect, useMemo, useState } from 'react'
import { alternatives, barView, cheaperElsewhere, fakeDiscount } from '../../lib/bar-rules'
import { canInject, pageKind } from '../../lib/merchant-page-detectors'
import { RequestError, send, type PageInfo } from '../../lib/messages'
import type { CompareRow, MerchantRate } from '../../lib/types'
import { BarViewUi } from './bar-view'
import { ComparePanel } from './compare-panel'
import { readPrices } from './price-reader'

const ERR: Record<string, string> = {
  not_logged_in: 'Bấm biểu tượng CanhGia trên thanh công cụ để đăng nhập trước.',
  rate_limited: 'Bạn thao tác quá nhanh, thử lại sau ít phút.',
  merchant_unavailable: 'Sàn này tạm thời chưa hỗ trợ hoàn tiền.',
}

export function BarContainer({ url, onClose }: { url: string; onClose: () => void }) {
  const [info, setInfo] = useState<PageInfo | null>(null)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [panel, setPanel] = useState(false)

  useEffect(() => {
    let live = true
    send('pageInfo', { url })
      .then((i) => live && setInfo(i))
      .catch((e) => console.warn('canhgia: pageInfo failed', e)) // silent on the page: no bar rather than a broken one
    return () => {
      live = false
    }
  }, [url])

  const m: MerchantRate | null = info?.merchant ?? null
  const kind = m ? pageKind(m.merchant_id, url) : 'other'
  const offer = info?.resolve?.offer ?? null
  const view = useMemo(() => {
    if (!info || !m) return null
    const px = kind === 'product' ? readPrices(document, m.merchant_id) : { current: null, original: null }
    const alts = alternatives(info.compare, offer?.id ?? null)
    return barView({
      eligible: offer ? offer.cashback_eligible : true,
      activation: info.activation,
      fake: fakeDiscount(px.current ?? offer?.price_vnd ?? null, px.original, info.history),
      cheaper: cheaperElsewhere(info.compare, offer?.id ?? null),
      alternatives: alts,
      maxRateBps: m.max_user_rate_bps,
    })
  }, [info, m, kind, offer])

  const activate = useCallback(
    async (merchantId: string, target?: string, newTab = false) => {
      setBusy(true)
      setError(null)
      try {
        await send('activate', { tabId: 0, merchantId, url: target, newTab }) // tabId is replaced by the background
      } catch (e) {
        setError(ERR[e instanceof RequestError ? e.message : ''] ?? 'Chưa kích hoạt được. Vui lòng thử lại.')
        setBusy(false)
      }
    },
    [],
  )

  if (!info || !m || !view || !canInject(m) || (kind !== 'product' && kind !== 'search')) return null
  const rates = Object.fromEntries(info.rates.map((r) => [r.merchant_id, r]))
  const cheaperId = 'cheaper' in view ? view.cheaper?.merchantId : undefined
  const buy = (r: CompareRow) => void activate(r.merchant_id, r.url ?? undefined, true)

  return (
    <>
      <BarViewUi
        view={view}
        merchantName={m.name}
        rateBps={info.resolve?.estimate?.vip_rate_bps || info.resolve?.estimate?.base_rate_bps || m.max_user_rate_bps}
        cashbackVnd={info.resolve?.estimate?.cashback_vnd ?? null}
        productPage={kind === 'product'}
        cheaperName={cheaperId ? info.compare.find((r) => r.merchant_id === cheaperId)?.shop_name ?? cheaperId : null}
        busy={busy}
        error={error}
        onActivate={() => void activate(m.merchant_id, kind === 'product' ? url : undefined)}
        onCompare={() => setPanel((v) => !v)}
        onClose={onClose}
      />
      {panel && info.compare.length > 0 && (
        <ComparePanel rows={info.compare} rates={rates} currentOfferId={offer?.id ?? null} history={info.history} onBuy={buy} onClose={() => setPanel(false)} />
      )}
    </>
  )
}
