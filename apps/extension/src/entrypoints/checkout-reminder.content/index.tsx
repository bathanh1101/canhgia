import { useEffect, useState } from 'react'
import { createRoot } from 'react-dom/client'
import '../../assets/ui.css'
import { formatRate } from '../../lib/format'
import { canInject, pageKind } from '../../lib/merchant-page-detectors'
import { send, type PageInfo } from '../../lib/messages'

function Toast({ url }: { url: string }) {
  const [info, setInfo] = useState<PageInfo | null>(null)
  const [open, setOpen] = useState(true)
  const [busy, setBusy] = useState(false)
  const [failed, setFailed] = useState(false)
  useEffect(() => {
    send('pageInfo', { url }).then(setInfo).catch((e) => console.warn('canhgia: pageInfo failed', e))
  }, [url])

  const m = info?.merchant
  if (!open || !info || !m || !canInject(m) || pageKind(m.merchant_id, url) !== 'checkout') return null
  const rate = formatRate(m.max_user_rate_bps)
  const activate = async () => {
    setBusy(true)
    setFailed(false)
    try {
      // no product URL at checkout: activation goes through the merchant campaign link
      await send('activate', { tabId: 0, merchantId: m.merchant_id })
    } catch {
      setFailed(true)
      setBusy(false)
    }
  }
  return info.activation ? (
    <div className="toast ok" role="status">
      <span className="ic">✓</span>
      <div style={{ flex: 1 }}><b>Hoàn tiền đang hoạt động</b><div className="cg-muted">Đơn này có thể được hoàn đến {rate} vào ví CanhGia.</div></div>
      <button className="x" onClick={() => setOpen(false)} aria-label="Đóng">✕</button>
    </div>
  ) : (
    <div className="toast warn" role="alert">
      <span className="ic">!</span>
      <div style={{ flex: 1, display: 'grid', gap: 6 }}>
        <b>Bạn chưa kích hoạt hoàn tiền!</b>
        <div className="cg-muted">{info.loggedIn ? `Kích hoạt trước khi thanh toán để nhận hoàn tiền đến ${rate}.` : 'Đăng nhập CanhGia (biểu tượng tiện ích) rồi kích hoạt trước khi thanh toán.'}</div>
        {failed && <div className="cg-err">Chưa kích hoạt được, thử lại nhé.</div>}
        {info.loggedIn && <button className="cg-btn" onClick={activate} disabled={busy}>Kích hoạt ngay</button>}
      </div>
      <button className="x" onClick={() => setOpen(false)} aria-label="Đóng">✕</button>
    </div>
  )
}

export default defineContentScript({
  matches: ['https://*.shopee.vn/*', 'https://*.lazada.vn/*', 'https://*.tiki.vn/*', 'https://*.tiktok.com/*'],
  cssInjectionMode: 'ui',
  async main(ctx) {
    let render: (url: string) => void = () => {}
    const ui = await createShadowRootUi(ctx, {
      name: 'canhgia-checkout-toast',
      position: 'inline',
      anchor: 'body',
      onMount: (container) => {
        const root = createRoot(container)
        render = (url) => root.render(<Toast key={url} url={url} />)
        render(location.href)
        return root
      },
      onRemove: (r) => r?.unmount(),
    })
    ui.mount()
    ctx.addEventListener(window, 'wxt:locationchange', ({ newUrl }) => render(newUrl.toString()))
  },
})
