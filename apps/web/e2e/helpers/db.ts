import { createHmac, randomUUID } from 'node:crypto'

// Local stack (public supabase-demo keys); override with env for another stack.
export const API = process.env.NEXT_PUBLIC_SUPABASE_URL ?? 'http://127.0.0.1:55321'
const ANON = process.env.SUPABASE_ANON_KEY ??
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0'
const SERVICE = process.env.SUPABASE_SERVICE_ROLE_KEY ??
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU'
const JWT_SECRET = process.env.JWT_SECRET ?? 'super-secret-jwt-token-with-at-least-32-characters-long'

export const USERS = {
  admin: '11111111-1111-1111-1111-111111111111',
  minh: '22222222-2222-2222-2222-222222222222',
  lan: '33333333-3333-3333-3333-333333333333',
}

const b64 = (o: object) => Buffer.from(JSON.stringify(o)).toString('base64url')
/** User JWT signed with the local JWT secret: stands in for a finished OTP (+TOTP) login for API-level checks. */
export function userJwt(sub: string, aal: 'aal1' | 'aal2' = 'aal1'): string {
  const now = Math.floor(Date.now() / 1000)
  const data = `${b64({ alg: 'HS256', typ: 'JWT' })}.${b64({ iss: `${API}/auth/v1`, aud: 'authenticated', role: 'authenticated', sub, aal, iat: now, exp: now + 3600 })}`
  return `${data}.${createHmac('sha256', JWT_SECRET).update(data).digest('base64url')}`
}

type Init = { method?: string; body?: unknown; jwt?: string; headers?: Record<string, string> }
/** PostgREST call as service_role (default) or as a user (jwt). */
export async function pg(path: string, { method = 'GET', body, jwt, headers }: Init = {}) {
  const res = await fetch(`${API}/rest/v1/${path}`, {
    method,
    headers: {
      apikey: jwt ? ANON : SERVICE, authorization: `Bearer ${jwt ?? SERVICE}`, 'content-type': 'application/json',
      prefer: 'return=representation', ...headers,
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  })
  const text = await res.text()
  return { status: res.status, body: text ? JSON.parse(text) : null }
}
export const rpc = (fn: string, args: object, jwt?: string) => pg(`rpc/${fn}`, { method: 'POST', body: args, jwt })

export async function mustOk<T>(r: Promise<{ status: number; body: T }>): Promise<T> {
  const x = await r
  if (x.status >= 300) throw new Error(`db ${x.status}: ${JSON.stringify(x.body)}`)
  return x.body
}

/** A pending withdrawal for `minh` with an unverified-name bank account (admin must verify before paying). */
export async function seedWithdrawal(amount: number) {
  const [bank] = await mustOk(pg('bank_accounts', {
    method: 'POST',
    body: { user_id: USERS.minh, bank_bin: '970436', account_number: String(Math.floor(Math.random() * 9e11) + 1e11), account_name: 'NGUYEN VAN MINH', account_name_norm: 'NGUYEN VAN MINH' },
  }))
  const [w] = await mustOk(pg('withdrawals', {
    method: 'POST',
    body: { request_key: randomUUID(), user_id: USERS.minh, amount, bank_account_id: bank.id, bank_bin: bank.bank_bin, account_number: bank.account_number, account_name: bank.account_name },
  }))
  return w as { id: string; amount: number }
}

/** One AccessTrade conversion pushed through the real ingest RPC (what sync-transactions calls). */
export async function ingestConversion(over: Record<string, unknown> = {}) {
  const id = Number(over.conversion_id ?? Date.now())
  const row = {
    conversion_id: id, transaction_id: `E2E${id}`, merchant: 'shopee', status: 0, is_confirmed: 0, commission: 100000,
    transaction_value: 2000000, product_price: 0, product_quantity: 1, update_time: new Date().toISOString(), utm_content: '', ...over,
  }
  const out = await mustOk(rpc('ingest_at_transactions', { p_job: 'e2e', p_rows: [row] })) as { status: string }[]
  return { id, code: row.transaction_id as string, status: out[0]?.status }
}

export async function seedComplaint(orderCode: string, valueVnd = 300000) {
  const day = new Date(Date.now() - 3 * 86_400_000).toISOString().slice(0, 10)
  const [r] = await mustOk(pg('missing_order_reports', {
    method: 'POST',
    body: { user_id: USERS.minh, merchant_id: 'shopee', order_code: orderCode, purchased_on: day, order_value_vnd: valueVnd, image_paths: [`${USERS.minh}/e2e.png`] },
  }))
  return r as { id: number; public_code: string }
}
