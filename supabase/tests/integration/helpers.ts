// Shared bits for the backend integration tests. Runs against the local stack (defaults = the public supabase-demo keys).
// Needs CRON_SECRET = the value the edge runtime was started with (see docs/deployment-guide.md "Local e2e stack").
export const API_URL = Deno.env.get('SUPABASE_URL') ?? 'http://127.0.0.1:55321'
export const ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY') ??
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0'
export const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ??
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU'
const JWT_SECRET = Deno.env.get('JWT_SECRET') ?? 'super-secret-jwt-token-with-at-least-32-characters-long'
export const CRON_SECRET = Deno.env.get('CRON_SECRET') ?? ''
export const MOCK_URL = 'http://127.0.0.1:8787'

export const USERS = {
  admin: '11111111-1111-1111-1111-111111111111',
  minh: '22222222-2222-2222-2222-222222222222',
  lan: '33333333-3333-3333-3333-333333333333',
}

const b64 = (b: ArrayBuffer | string) =>
  btoa(typeof b === 'string' ? b : String.fromCharCode(...new Uint8Array(b))).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')

/** User JWT signed with the local stack's JWT secret (test-only; stands in for a completed OTP + TOTP login). */
export async function userJwt(sub: string, aal: 'aal1' | 'aal2' = 'aal1'): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  const data = `${b64(JSON.stringify({ alg: 'HS256', typ: 'JWT' }))}.${b64(JSON.stringify({
    iss: `${API_URL}/auth/v1`, aud: 'authenticated', role: 'authenticated', sub, aal, iat: now, exp: now + 3600,
  }))}`
  const k = await crypto.subtle.importKey('raw', new TextEncoder().encode(JWT_SECRET), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign'])
  return `${data}.${b64(await crypto.subtle.sign('HMAC', k, new TextEncoder().encode(data)))}`
}

export async function sha256hex(s: string): Promise<string> {
  return [...new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(s)))].map((x) => x.toString(16).padStart(2, '0')).join('')
}

export async function fn(name: string, body: unknown, headers: Record<string, string> = {}) {
  const res = await fetch(`${API_URL}/functions/v1/${name}`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', apikey: ANON_KEY, ...headers },
    body: JSON.stringify(body),
  })
  return { status: res.status, body: await res.json().catch(() => null) }
}

/** Test-only reset of the rate limiters (AT token bucket, per-IP extension-login codes) so reruns and fast suites never trip them. */
export async function resetLimits() {
  await rest('at_rate_bucket?bucket=eq.transactions', { method: 'PATCH', body: JSON.stringify({ tokens: 5 }) })
  await rest('extension_login_codes?code=not.is.null', { method: 'DELETE' })
}

export async function syncRecent() {
  await resetLimits()
  const r = await fn('sync-transactions', { window: 'recent' }, { 'x-cron-secret': CRON_SECRET })
  if (r.status !== 200 || r.body?.error) throw new Error(`sync-transactions ${r.status} ${JSON.stringify(r.body)}`)
  return r
}

export async function setConversions(conversions: unknown[]) {
  await fetch(`${MOCK_URL}/__control`, { method: 'POST', body: JSON.stringify({ conversions }) })
}

const svc = { apikey: SERVICE_KEY, authorization: `Bearer ${SERVICE_KEY}`, 'content-type': 'application/json' }

export async function rest(path: string, init: RequestInit = {}) {
  const res = await fetch(`${API_URL}/rest/v1/${path}`, { ...init, headers: { ...svc, ...(init.headers as object) } })
  return { status: res.status, body: await res.json().catch(() => null) }
}

/** create_click allows 30 clicks/user/hour; age the fixtures' recent clicks so repeated runs (and the e2e suites) never trip it. */
export async function ageRecentClicks() {
  const since = new Date(Date.now() - 3600_000).toISOString()
  await rest(`clicks?created_at=gt.${since}`, { method: 'PATCH', body: JSON.stringify({ created_at: new Date(Date.now() - 2 * 3600_000).toISOString() }) })
}

export async function createClick(userId: string, merchantId: string, url: string): Promise<{ click_id: number; utm_content: string }> {
  await ageRecentClicks()
  const r = await rest('rpc/create_click', {
    method: 'POST',
    body: JSON.stringify({
      p_user_id: userId, p_merchant_id: merchantId, p_origin_url: url, p_resolved_url: url,
      p_offer_id: null, p_source: 'app', p_device_hash: null,
    }),
  })
  if (r.status !== 200) throw new Error(`create_click ${r.status} ${JSON.stringify(r.body)}`)
  return r.body[0]
}

export const getOrder = async (conversionId: number) =>
  (await rest(`orders?conversion_id=eq.${conversionId}&select=id,merchant_id,user_id,at_status,credit_state,commission_vnd,user_cashback_vnd`)).body[0]

export const getWallet = async (userId: string) => (await rest(`wallets?user_id=eq.${userId}&select=pending_vnd,held_vnd,available_vnd`)).body[0]
