// Backend integration: extension QR-pair login. Contract: docs/backend-contracts.md (extension-login row).
import { beforeEach, describe, it } from 'jsr:@std/testing@1.0.0/bdd'
import { assert, assertEquals } from 'jsr:@std/assert@1.0.0'
import { ANON_KEY, API_URL, fn, resetLimits, sha256hex, USERS, userJwt } from './helpers.ts'

async function start() {
  const secret = crypto.randomUUID()
  const r = await fn('extension-login', { action: 'start', client_secret_hash: await sha256hex(secret) })
  assertEquals(r.status, 200)
  return { secret, ...r.body as { code: string; expires_at: string } }
}
const poll = (code: string, client_secret: string) => fn('extension-login', { action: 'poll', code, client_secret })

async function approve(code: string, sub: string) {
  const res = await fetch(`${API_URL}/rest/v1/rpc/approve_extension_login`, {
    method: 'POST',
    headers: { apikey: ANON_KEY, authorization: `Bearer ${await userJwt(sub)}`, 'content-type': 'application/json' },
    body: JSON.stringify({ p_code: code }),
  })
  return res.status
}

describe('extension-login', () => {
  beforeEach(resetLimits) // start is limited to 5 codes / IP / 10 min
  it('start returns a uuid code and a future ISO expires_at', async () => {
    const s = await start()
    assert(/^[0-9a-f-]{36}$/.test(s.code))
    assert(Date.parse(s.expires_at) > Date.now(), `expires_at ${s.expires_at} not in the future`)
  })

  it('start rejects a client_secret_hash that is not sha256 hex', async () => {
    assertEquals((await fn('extension-login', { action: 'start', client_secret_hash: 'secret_hash' })).status, 400)
  })

  it('poll before approve -> 202 pending', async () => {
    const s = await start()
    const r = await poll(s.code, s.secret)
    assertEquals([r.status, r.body.status], [202, 'pending'])
  })

  it('poll with the wrong secret -> 410 code_invalid', async () => {
    const s = await start()
    const r = await poll(s.code, 'not-the-secret')
    assertEquals([r.status, r.body.error], [410, 'code_invalid'])
  })

  it('approve -> poll returns token_hash once, then 410', async () => {
    const s = await start()
    const st = await approve(s.code, USERS.minh)
    assert(st === 200 || st === 204, `approve status ${st}`)
    const ok = await poll(s.code, s.secret)
    assertEquals(ok.status, 200)
    assertEquals(typeof ok.body.token_hash, 'string')
    assertEquals((await poll(s.code, s.secret)).status, 410)
  })
})
