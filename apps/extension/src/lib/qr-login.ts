import { ApiError, type EdgePost, expectOk } from './edge-client'

export interface QrSession {
  code: string
  secret: string
  expiresAt: number
}

const hex = (b: Uint8Array) => [...b].map((x) => x.toString(16).padStart(2, '0')).join('')

export async function sha256Hex(s: string): Promise<string> {
  return hex(new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(s))))
}

/** Secret stays in memory of the background; only sha256(secret) leaves. QR payload carries the code only. */
export async function qrStart(post: EdgePost): Promise<QrSession & { payload: string }> {
  const secret = hex(crypto.getRandomValues(new Uint8Array(32)))
  const j = expectOk(await post('extension-login', { action: 'start', client_secret_hash: await sha256Hex(secret) }, false)) as { code?: unknown; expires_at?: unknown }
  const expiresAt = typeof j.expires_at === 'string' ? Date.parse(j.expires_at) : NaN
  if (typeof j.code !== 'string' || Number.isNaN(expiresAt)) throw new ApiError(502, 'bad_response')
  return { code: j.code, secret, expiresAt, payload: `canhgia-ext:${j.code}` }
}

export type QrPoll = { state: 'pending' } | { state: 'expired' } | { state: 'approved'; tokenHash: string }

export async function qrPoll(post: EdgePost, s: QrSession, now = Date.now()): Promise<QrPoll> {
  if (now >= s.expiresAt) return { state: 'expired' }
  const r = await post('extension-login', { action: 'poll', code: s.code, client_secret: s.secret }, false)
  if (r.status === 202) return { state: 'pending' }
  if (r.status === 410) return { state: 'expired' }
  const j = expectOk(r) as { token_hash?: unknown }
  if (typeof j.token_hash !== 'string' || !j.token_hash) throw new ApiError(502, 'bad_response')
  return { state: 'approved', tokenHash: j.token_hash }
}
