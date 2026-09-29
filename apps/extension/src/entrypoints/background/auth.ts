import { parseAuthRedirect } from '../../lib/validators'
import { qrPoll, qrStart, type QrSession } from '../../lib/qr-login'
import type { QrInfo, QrPollReply } from '../../lib/messages'
import { edgePost, supabase } from './supabase'

export async function signInGoogle(): Promise<true> {
  const redirectTo = chrome.identity.getRedirectURL()
  const { data, error } = await supabase.auth.signInWithOAuth({ provider: 'google', options: { skipBrowserRedirect: true, redirectTo } })
  if (error || !data.url) throw new Error(error?.message ?? 'oauth_url_missing')
  const back = await chrome.identity.launchWebAuthFlow({ url: data.url, interactive: true })
  if (!back) throw new Error('auth_cancelled')
  const { error: e2 } = await supabase.auth.setSession(parseAuthRedirect(back))
  if (e2) throw new Error(e2.message)
  return true
}

// Memory only (never storage): dies with the service worker, which is the safe failure.
let qr: QrSession | null = null

export async function startQr(): Promise<QrInfo> {
  const s = await qrStart(edgePost)
  qr = { code: s.code, secret: s.secret, expiresAt: s.expiresAt }
  return { payload: s.payload, expiresAt: s.expiresAt }
}

export async function pollQr(): Promise<QrPollReply> {
  if (!qr) return { state: 'expired' }
  const r = await qrPoll(edgePost, qr)
  if (r.state === 'pending') return r
  if (r.state === 'expired') {
    qr = null
    return r
  }
  const { error } = await supabase.auth.verifyOtp({ token_hash: r.tokenHash, type: 'magiclink' })
  qr = null
  if (error) throw new Error(error.message)
  return { state: 'approved' }
}

export async function signOut(): Promise<true> {
  qr = null
  const { error } = await supabase.auth.signOut({ scope: 'local' })
  if (error) throw new Error(error.message)
  return true
}
