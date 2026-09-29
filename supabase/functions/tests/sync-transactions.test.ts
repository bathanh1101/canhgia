import { assert, assertEquals } from '@std/assert'
import { makeHandler } from '../sync-transactions/handler.ts'
import { createAtClient } from '../_shared/accesstrade-client.ts'
import { createSyncCursor } from '../_shared/sync-cursor.ts'
import { fakeBucket, type FakeDb, makeFakeDb, syncHandlers } from './fake-db.ts'
import { makeConversions, startMock } from './mock-accesstrade.ts'

type Row = Record<string, unknown>
const T0 = Date.parse('2026-09-29T12:00:00Z')

function setup(o: { stepMs?: number } = {}) {
  let t = T0
  const clock = () => t
  const orders = new Map<number, Row>()
  const sleeps: number[] = []
  const mock = startMock({ clock })
  const db: FakeDb = makeFakeDb({
    handlers: {
      at_rate_limit_take: fakeBucket(clock),
      ...syncHandlers(() => db, clock),
      ingest_at_transactions: (a) =>
        (a.p_rows as Row[]).map((r) => {
          if (typeof r.conversion_id !== 'number') return { conversion_id: null, status: 'error' }
          const prior = orders.get(r.conversion_id)
          orders.set(r.conversion_id, r)
          if (prior && prior.update_time === r.update_time && prior.commission === r.commission) {
            return { conversion_id: r.conversion_id, status: 'skipped' }
          }
          return {
            conversion_id: r.conversion_id,
            status: prior ? 'updated' : /^u\d+c\d+$/.test(String(r.utm_content)) ? 'inserted' : 'unmatched',
          }
        }),
    },
  })
  const at = createAtClient({
    db,
    baseUrl: mock.url,
    token: 'test-token',
    now: clock,
    sleep: (ms) => {
      sleeps.push(ms)
      t += ms
      return Promise.resolve()
    },
    fetchFn: (i, init) => {
      t += o.stepMs ?? 0
      return fetch(i, init)
    },
  })
  const h = makeHandler({ db, at, cursor: createSyncCursor(db), now: clock, cronSecret: 's' })
  const run = async (window: 'recent' | 'older' = 'recent') => {
    const res = await h(new Request('http://x/', { method: 'POST', headers: { 'x-cron-secret': 's' }, body: JSON.stringify({ window }) }))
    return { status: res.status, body: await res.json() as Row }
  }
  const state = (job = 'tx_recent') => (db.tables.sync_state ?? []).find((r) => r.job === job)!
  return {
    mock,
    db,
    orders,
    run,
    state,
    sleeps,
    advance: (ms: number) => {
      t += ms
    },
    now: clock,
  }
}

Deno.test('rejects missing cron secret', async () => {
  const s = setup()
  const res = await makeHandler({ db: s.db, at: undefined as never, cursor: createSyncCursor(s.db), cronSecret: 's' })(
    new Request('http://x/', { method: 'POST', body: '{"window":"recent"}' }),
  )
  assertEquals(res.status, 403)
  await s.mock.close()
})

Deno.test('ingests two pages, saves cursor between pages and clears it on success', async () => {
  const s = setup()
  s.mock.state.conversions = makeConversions(130)
  const { body } = await s.run()
  assertEquals([body.pages, body.inserted, body.done], [2, 130, true])
  assertEquals(s.orders.size, 130)
  assertEquals(s.mock.calls.map((c) => c.params.page), ['1', '2'])
  assert(s.db.calls.some((c) => c.fn === 'sync_save' && (c.args.p_cursor as Row).page === 2))
  assertEquals(s.state().cursor, null)
  assertEquals(s.state().last_success_at, '2026-09-29T12:00:00Z')
  assertEquals(s.state().locked_until, null)
})

Deno.test('replaying the same rows is idempotent', async () => {
  const s = setup()
  s.mock.state.conversions = makeConversions(130)
  await s.run()
  s.advance(3600_000)
  const { body } = await s.run()
  assertEquals([body.inserted, body.skipped, s.orders.size], [0, 130, 130])
})

Deno.test('window moves: next run starts 30 min before the last success', async () => {
  const s = setup()
  await s.run()
  assertEquals(s.mock.calls[0].params.since, '2026-09-26T12:00:00Z') // first run: now - 3d
  s.advance(3600_000)
  await s.run()
  assertEquals(s.mock.calls[1].params.since, '2026-09-29T11:30:00Z')
  assertEquals(s.mock.calls[1].params.until, '2026-09-29T13:00:00Z')
})

Deno.test('429 mid-run keeps the cursor and the next run resumes at the failed page', async () => {
  const s = setup()
  s.mock.state.conversions = makeConversions(250)
  s.mock.state.fail = { path: '/v1/transactions', onCall: 2, status: 429 }
  const first = await s.run()
  assertEquals([first.body.error, first.body.done, first.body.pages], ['rate_limited', false, 1])
  assertEquals((s.state().cursor as Row).page, 2)
  assertEquals(s.state().last_success_at, null)
  assertEquals(s.state().locked_until, null)
  const second = await s.run()
  assertEquals([second.body.done, s.orders.size], [true, 250])
  assertEquals(s.mock.calls.at(-1)!.params.page, '3')
})

Deno.test('poison row: 1 bad of 100 -> 99 ingested, error counted, page continues', async () => {
  const s = setup()
  const rows = makeConversions(100)
  rows[40] = { ...rows[40], conversion_id: 'not-a-number' }
  s.mock.state.conversions = rows
  const { body } = await s.run()
  assertEquals([body.inserted, body.errors, body.done], [99, 1, true])
})

Deno.test('empty bucket: waits for refill instead of failing', async () => {
  const s = setup()
  s.mock.state.conversions = makeConversions(1200) // 12 pages > bucket capacity of 10
  const { body } = await s.run()
  assertEquals([body.pages, body.done, body.error], [13, true, undefined])
  assert(s.sleeps.length >= 3 && s.sleeps.every((ms) => ms === 6000))
})

Deno.test('deadline exit: cursor kept, no success recorded, resumable', async () => {
  const s = setup({ stepMs: 60_000 })
  s.mock.state.conversions = makeConversions(600)
  const { body } = await s.run()
  assertEquals(body.done, false)
  assertEquals(body.error, undefined)
  assertEquals(s.state().last_success_at, null)
  assert(s.state().cursor !== null)
})

Deno.test('second run while locked is skipped', async () => {
  const s = setup()
  s.state() // no-op
  await s.db.rpc('sync_lock', { p_job: 'tx_recent', p_ttl_s: 150 })
  assertEquals((await s.run()).body.skipped, 'locked')
})

Deno.test('older sweep walks 7d slices and finishes at now-3d', async () => {
  const s = setup()
  const { body } = await s.run('older')
  assertEquals(body.done, true)
  assertEquals(s.mock.calls.length, 26) // 177 days / 7 = 25.3 -> 26 slices
  assertEquals(s.state('tx_older').last_success_at, '2026-09-26T12:00:00Z')
})

Deno.test('sub1 fallback rebuilds utm_content from the clicks table', async () => {
  const s = setup()
  s.db.tables.clicks = [{ id: 5, utm_content: 'u7c5' }]
  s.mock.state.conversions = makeConversions(2, 1, { utm_content: '' }).map((r, i) => (i === 0 ? { ...r, sub1: '5' } : r))
  const { body } = await s.run()
  assertEquals([body.inserted, body.unmatched], [1, 1])
  const sent = s.db.calls.find((c) => c.fn === 'ingest_at_transactions')!.args.p_rows as Row[]
  assertEquals(sent[0].utm_content, 'u7c5')
  assertEquals(sent[1].utm_content, '')
})

Deno.test('invalid window is rejected', async () => {
  const s = setup()
  const res = await makeHandler({ db: s.db, at: undefined as never, cursor: createSyncCursor(s.db), cronSecret: 's' })(
    new Request('http://x/', { method: 'POST', headers: { 'x-cron-secret': 's' }, body: '{"window":"weekly"}' }),
  )
  assertEquals(res.status, 400)
})
