import { useCallback, useEffect, useState } from 'react'
import { LoginPanel } from '../../components/login-panel'
import { send, type PopupData } from '../../lib/messages'
import { AccountHeader, ActivatedView, IdleView, NotActivatedView, RecentOrders } from './views'
import { LANDING_URL } from '../../lib/config'

export function App() {
  const [data, setData] = useState<PopupData | null>(null)
  const [tab, setTab] = useState<{ id: number; url: string } | null>(null)
  const [error, setError] = useState<string | null>(null)

  const load = useCallback(async () => {
    try {
      const [t] = await chrome.tabs.query({ active: true, currentWindow: true })
      const t2 = { id: t?.id ?? 0, url: t?.url ?? '' }
      setTab(t2)
      setData(await send('popupData', { tabUrl: t2.url }))
      setError(null)
    } catch {
      setError('Không tải được dữ liệu. Kiểm tra kết nối rồi mở lại tiện ích.')
    }
  }, [])
  useEffect(() => void load(), [load])

  if (error) return <div style={{ padding: 16 }}><p className="cg-err">{error}</p></div>
  if (!data || !tab) return <div style={{ padding: 16 }} className="cg-muted">Đang tải…</div>

  if (!data.loggedIn) {
    return (
      <div style={{ padding: 16, display: 'grid', gap: 12 }}>
        <span className="cg-logo"><i>₫</i>CanhGia</span>
        <div><h3 style={{ margin: 0 }}>Đăng nhập để nhận hoàn tiền</h3><p className="cg-muted">Dùng chung tài khoản với app CanhGia, tiền hoàn về cùng một ví.</p></div>
        <LoginPanel onDone={() => void load()} />
      </div>
    )
  }

  const m = data.merchant
  return (
    <div style={{ padding: 16, display: 'grid', gap: 12 }}>
      {data.user && <AccountHeader user={data.user} onSignOut={async () => { await send('signOut', {}); void load() }} />}
      {!m && <IdleView />}
      {m && data.activation && <ActivatedView merchant={m} expiresAt={data.activation.expiresAt} onExpire={() => void load()} />}
      {m && !data.activation && <NotActivatedView merchant={m} tabId={tab.id} tabUrl={tab.url} />}
      {data.activation && <RecentOrders orders={data.orders} />}
      <a className="cg-link" href={LANDING_URL} target="_blank" rel="noreferrer">Mở ví CanhGia ›</a>
    </div>
  )
}
