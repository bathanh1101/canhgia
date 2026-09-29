import { assertEquals } from '@std/assert'
import { makeHandler } from '../extension-login/handler.ts'
import { makeFakeDb } from './fake-db.ts'

const HASH = 'a'.repeat(64)
const CODE = '11111111-2222-3333-4444-555555555555'
type Row = Record<string, unknown>

function setup() {
  const started = new Map<string, number>() // ip -> count
  const codes = new Map<string, { hash: string; status: string; used: boolean }>()
  const err = (m: string): never => {
    throw new Error(m)
  }
  const db = makeFakeDb({
    handlers: {
      start_extension_login: (a) => {
        const ip = String(a.p_ip)
        started.set(ip, (started.get(ip) ?? 0) + 1)
        if (started.get(ip)! > 5) err('rate_limited')
        codes.set(CODE, { hash: String(a.p_secret_hash), status: 'pending', used: false })
        return [{ code: CODE, expires_at: '2026-09-29T12:02:00Z' }]
      },
      consume_extension_login: (a) => {
        const c = codes.get(String(a.p_code))
        // real SQL hashes p_secret with sha256; the fake compares the precomputed hash
        if (!c || c.used || c.hash !== hashOf(String(a.p_secret))) err('code_invalid')
        if (c!.status === 'pending') err('code_pending')
        c!.used = true
        return 'user-1'
      },
    },
    auth: {
      admin: {
        getUserById: () => Promise.resolve({ data: { user: { email: 'a@b.vn' } }, error: null }),
        generateLink: (a: Row) => Promise.resolve({ data: { properties: { hashed_token: `ht-${a.email}` } }, error: null }),
      },
    },
  })
  const h = makeHandler({ db })
  const call = async (body: Row, ip: string | null = '203.0.113.9') => {
    const headers: Record<string, string> = { 'user-agent': 'Chrome/1' }
    if (ip) headers['x-forwarded-for'] = `6.6.6.6, ${ip}`
    const res = await h(new Request('http://x/', { method: 'POST', headers, body: JSON.stringify(body) }))
    return { status: res.status, body: await res.json() as Row }
  }
  return { db, codes, call }
}

const SECRET = 'my-secret'
const hashes = new Map<string, string>()
function hashOf(s: string): string {
  return hashes.get(s) ?? s
}
async function registerSecret(s: string) {
  const d = new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(s)))
  const hex = Array.from(d, (b) => b.toString(16).padStart(2, '0')).join('')
  hashes.set(s, hex)
  return hex
}

Deno.test('start returns code and passes last-hop IP + user agent to SQL', async () => {
  const s = setup()
  const r = await s.call({ action: 'start', client_secret_hash: HASH })
  assertEquals([r.status, r.body.code], [200, CODE])
  const a = s.db.calls[0].args
  assertEquals([a.p_ip, a.p_user_agent, a.p_secret_hash], ['203.0.113.9', 'Chrome/1', HASH])
})

Deno.test('start: malformed hash, missing/invalid IP -> 400 invalid_input', async () => {
  const s = setup()
  assertEquals((await s.call({ action: 'start', client_secret_hash: 'short' })).body.error, 'invalid_input')
  assertEquals((await s.call({ action: 'start', client_secret_hash: HASH }, null)).status, 400)
  assertEquals((await s.call({ action: 'start', client_secret_hash: HASH }, 'not-an-ip')).status, 400)
  assertEquals(s.db.calls.length, 0)
})

Deno.test('6th start from one IP in the window -> 429 rate_limited', async () => {
  const s = setup()
  for (let i = 0; i < 5; i++) assertEquals((await s.call({ action: 'start', client_secret_hash: HASH })).status, 200)
  const r = await s.call({ action: 'start', client_secret_hash: HASH })
  assertEquals([r.status, r.body.error], [429, 'rate_limited'])
  assertEquals((await s.call({ action: 'start', client_secret_hash: HASH }, '198.51.100.1')).status, 200)
})

Deno.test('poll: pending -> 202; approved -> token_hash; second poll -> 410; wrong secret -> 410', async () => {
  const s = setup()
  const hash = await registerSecret(SECRET)
  await s.call({ action: 'start', client_secret_hash: hash })
  assertEquals(await s.call({ action: 'poll', code: CODE, client_secret: SECRET }), { status: 202, body: { status: 'pending' } })
  assertEquals((await s.call({ action: 'poll', code: CODE, client_secret: 'wrong' })).body.error, 'code_invalid')
  s.codes.get(CODE)!.status = 'approved'
  assertEquals(await s.call({ action: 'poll', code: CODE, client_secret: SECRET }), { status: 200, body: { token_hash: 'ht-a@b.vn' } })
  assertEquals(await s.call({ action: 'poll', code: CODE, client_secret: SECRET }), { status: 410, body: { error: 'code_invalid' } })
})

Deno.test('poll: bad code format and unknown action -> 400', async () => {
  const s = setup()
  assertEquals((await s.call({ action: 'poll', code: 'nope', client_secret: 'x' })).status, 400)
  assertEquals((await s.call({ action: 'steal' })).status, 400)
})

Deno.test('client IP order: cf-connecting-ip, then last XFF hop, never the spoofable first hop', async () => {
  const s = setup()
  const start = (h: Record<string, string>) =>
    makeHandler({ db: s.db })(
      new Request('http://x/', { method: 'POST', headers: h, body: JSON.stringify({ action: 'start', client_secret_hash: HASH }) }),
    )
  await start({ 'cf-connecting-ip': '198.51.100.7', 'x-forwarded-for': '6.6.6.6, 203.0.113.1' })
  await start({ 'x-forwarded-for': '6.6.6.6, 203.0.113.1' })
  assertEquals(s.db.calls.filter((c) => c.fn === 'start_extension_login').map((c) => c.args.p_ip), ['198.51.100.7', '203.0.113.1'])
})

Deno.test('start: global pending-code cap -> 429 without calling SQL', async () => {
  const s = setup()
  const far = new Date(Date.now() + 60_000).toISOString()
  s.db.tables.extension_login_codes = Array.from({ length: 200 }, () => ({ status: 'pending', expires_at: far }))
  const r = await s.call({ action: 'start', client_secret_hash: HASH })
  assertEquals([r.status, r.body.error, s.db.calls.length], [429, 'rate_limited', 0])
})

Deno.test('poll: transient auth-admin failure is retried after consume', async () => {
  let n = 0
  const db = makeFakeDb({
    handlers: { consume_extension_login: () => 'user-1' },
    auth: {
      admin: {
        getUserById: () => Promise.resolve({ data: { user: { email: 'a@b.vn' } }, error: null }),
        generateLink: () =>
          Promise.resolve(
            ++n < 3 ? { data: null, error: { message: 'boom' } } : { data: { properties: { hashed_token: 'ht' } }, error: null },
          ),
      },
    },
  })
  const res = await makeHandler({ db })(
    new Request('http://x/', {
      method: 'POST',
      body: JSON.stringify({ action: 'poll', code: CODE, client_secret: 's' }),
    }),
  )
  assertEquals([res.status, (await res.json()).token_hash, n], [200, 'ht', 3])
})
