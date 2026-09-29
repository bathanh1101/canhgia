import { assert, assertEquals, assertRejects } from '@std/assert'
import { AtError, createAtClient } from '../_shared/accesstrade-client.ts'
import { fakeBucket, makeFakeDb } from './fake-db.ts'
import { startMock } from './mock-accesstrade.ts'

function setup(tokenOk = true) {
  let t = 0
  const sleeps: number[] = []
  const take = fakeBucket(() => t)
  const db = makeFakeDb({ handlers: { at_rate_limit_take: (a) => (tokenOk ? take(a) : false) } })
  const mock = startMock()
  const at = createAtClient({
    db,
    baseUrl: mock.url,
    token: 'tok',
    now: () => t,
    sleep: (ms) => {
      sleeps.push(ms)
      t += ms
      return Promise.resolve()
    },
  })
  return { at, mock, sleeps, db }
}
const tx = { bucket: 'transactions' as const, params: { page: 1 } }

Deno.test('sends token auth header and query params', async () => {
  const s = setup()
  await s.at.get('/v1/transactions', tx)
  assertEquals(s.mock.calls[0].params, { page: '1' })
  await s.mock.close()
})

Deno.test('5xx retried with back-off then upstream error', async () => {
  const s = setup()
  s.mock.state.fail = { path: '/v1/transactions', onCall: 1, status: 502 }
  await s.at.get('/v1/transactions', { ...tx, retries: [1000, 4000] })
  assertEquals([s.mock.calls.length, s.sleeps], [2, [1000]])
  const e = await assertRejects(() => s.at.get('/v1/nope', { ...tx, retries: [10] }), AtError)
  assertEquals(e.kind, 'upstream') // 404 is not retried
  await s.mock.close()
})

Deno.test('429 -> rate_limited without retry; 401 -> auth', async () => {
  const s = setup()
  s.mock.state.fail = { path: '/v1/transactions', onCall: 1, status: 429 }
  assertEquals((await assertRejects(() => s.at.get('/v1/transactions', { ...tx, retries: [1] }), AtError)).kind, 'rate_limited')
  assertEquals(s.mock.calls.length, 1)
  s.mock.state.fail = { path: '/v1/transactions', onCall: 2, status: 401 }
  assertEquals((await assertRejects(() => s.at.get('/v1/transactions', tx), AtError)).kind, 'auth')
  await s.mock.close()
})

Deno.test('empty bucket with waitMs 0 fails fast without calling AccessTrade', async () => {
  const s = setup(false)
  assertEquals((await assertRejects(() => s.at.get('/v1/transactions', tx), AtError)).kind, 'rate_limited')
  assertEquals(s.mock.calls.length, 0)
  const e = await assertRejects(() => s.at.get('/v1/transactions', { ...tx, waitMs: 13_000 }), AtError)
  assert(e.message.includes('bucket') && s.sleeps.length === 2)
  await s.mock.close()
})

Deno.test('non-JSON body -> upstream', async () => {
  const s = setup()
  const server = Deno.serve({ port: 0, onListen: () => {} }, () => new Response('<html>'))
  const at = createAtClient({ db: s.db, baseUrl: `http://localhost:${server.addr.port}`, token: 't', sleep: () => Promise.resolve() })
  assertEquals((await assertRejects(() => at.get('/x', tx), AtError)).kind, 'upstream')
  await server.shutdown()
  await s.mock.close()
})
