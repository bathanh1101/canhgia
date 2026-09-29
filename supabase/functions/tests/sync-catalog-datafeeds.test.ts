import { assertEquals } from '@std/assert'
import { makeHandler as datafeeds } from '../sync-datafeeds/handler.ts'
import { makeHandler as catalog } from '../sync-catalog/handler.ts'
import { createAtClient } from '../_shared/accesstrade-client.ts'
import { createSyncCursor } from '../_shared/sync-cursor.ts'
import type { MerchantRow } from '../_shared/merchant-url-parser.ts'
import { fakeBucket, type FakeDb, makeFakeDb, syncHandlers } from './fake-db.ts'
import { startMock } from './mock-accesstrade.ts'
import feedFixture from './fixtures/datafeeds.json' with { type: 'json' }

type Row = Record<string, unknown>
const T0 = Date.parse('2026-09-29T12:00:00Z')
const M = (id: string, domains: string[], camp: string): MerchantRow => ({
  id,
  domains,
  at_campaign_id: camp,
  link_api: 'product_link',
  datafeed_enabled: id === 'shopee',
  activation_hours: 168,
})
const MERCHANTS = [M('shopee', ['shopee.vn', 'shp.ee'], '4751584435713464237'), M('tiki', ['tiki.vn'], '6023573823797709038')]

function setup() {
  let t = T0
  const clock = () => t
  const mock = startMock({ clock })
  const db: FakeDb = makeFakeDb({
    handlers: {
      at_rate_limit_take: fakeBucket(clock),
      ...syncHandlers(() => db, clock),
      upsert_offers: (a) => [{ upserted: (a.p_rows as Row[]).length, snapshots: 0 }],
      upsert_vouchers: (a) => (a.p_rows as Row[]).length,
      assign_product_groups: () => null,
      evaluate_price_alerts: () => null,
    },
  })
  const at = createAtClient({
    db,
    baseUrl: mock.url,
    token: 'tok',
    now: clock,
    sleep: (ms) => {
      t += ms
      return Promise.resolve()
    },
  })
  const deps = { db, at, cursor: createSyncCursor(db), merchants: () => Promise.resolve(MERCHANTS), now: clock, cronSecret: 's' }
  const post = async (h: ReturnType<typeof datafeeds>, body: Row) => {
    const res = await h(new Request('http://x/', { method: 'POST', headers: { 'x-cron-secret': 's' }, body: JSON.stringify(body) }))
    return { status: res.status, body: await res.json() as Row }
  }
  return {
    mock,
    db,
    deps,
    post,
    advance: (ms: number) => {
      t += ms
    },
  }
}

Deno.test('datafeeds backfill: maps rows, skips short hosts, runs 02b post-calls, then no-ops', async () => {
  const s = setup()
  const r = await s.post(datafeeds(s.deps), { mode: 'backfill' })
  assertEquals([r.body.merchant, r.body.done, r.body.offers], ['shopee', true, feedFixture.data.length])
  assertEquals(s.mock.calls.map((c) => c.params.domain), ['shopee.vn']) // shp.ee skipped, tiki not enabled
  const rows = s.db.calls.find((c) => c.fn === 'upsert_offers')!.args.p_rows as Row[]
  assertEquals(rows[0].external_product_id, '14346466.255489769') // same id resolve-url extracts from the URL
  assertEquals(s.db.calls.filter((c) => ['assign_product_groups', 'evaluate_price_alerts'].includes(c.fn)).length, 2)
  const again = await s.post(datafeeds(s.deps), { mode: 'backfill' })
  assertEquals([again.body.done, again.body.pages, s.mock.calls.length], [true, 0, 1])
})

Deno.test('datafeeds backfill pages until a short page and resumes after 429', async () => {
  const s = setup()
  s.mock.state.feed = Array.from({ length: 250 }, (_, i) => ({ ...feedFixture.data[0], url: `https://shopee.vn/product/1/${i + 1}` }))
  s.mock.state.fail = { path: '/v1/datafeeds', onCall: 2, status: 429 }
  const first = await s.post(datafeeds(s.deps), { mode: 'backfill' })
  assertEquals([first.body.error, first.body.done, first.body.offers], ['rate_limited', false, 200])
  const second = await s.post(datafeeds(s.deps), { mode: 'backfill' })
  assertEquals([second.body.done, second.body.offers, s.mock.calls.at(-1)!.params.page], [true, 50, '2'])
})

Deno.test('datafeeds delta sends update_from=yesterday (ICT) once per day', async () => {
  const s = setup()
  await s.post(datafeeds(s.deps), { mode: 'delta' })
  assertEquals(s.mock.calls[0].params.update_from, '28-09-2026')
  s.advance(10 * 60_000)
  await s.post(datafeeds(s.deps), { mode: 'delta' })
  assertEquals(s.mock.calls.length, 1)
})

Deno.test('datafeeds: bad mode 400, missing secret 403', async () => {
  const s = setup()
  assertEquals((await s.post(datafeeds(s.deps), { mode: 'x' })).status, 400)
  const res = await datafeeds(s.deps)(new Request('http://x/', { method: 'POST', body: '{"mode":"delta"}' }))
  assertEquals(res.status, 403)
})

Deno.test('catalog vouchers: maps AT offers to upsert_vouchers rows (link, not aff_link)', async () => {
  const s = setup()
  const r = await s.post(catalog(s.deps), { what: 'vouchers' })
  assertEquals(r.body.done, true)
  const first = (s.db.calls.find((c) => c.fn === 'upsert_vouchers')!.args.p_rows as Row[])[0]
  assertEquals(first.external_id, 'shopee-1519184237858828')
  assertEquals(first.code, 'LIFE30AF')
  assertEquals(first.ends_at, '2026-09-30T23:59:59+07:00')
  assertEquals(String(first.url).startsWith('https://shopee.vn/search'), true)
  assertEquals(s.mock.calls.every((c) => c.params.domain !== undefined), true)
})

Deno.test('catalog campaigns: reports unapproved merchants, never calls commission_policies', async () => {
  const s = setup()
  const r = await s.post(catalog(s.deps), { what: 'campaigns' })
  assertEquals(r.body.unapproved_merchants, ['shopee', 'tiki'])
  assertEquals([r.body.commissions, r.body.warning], [0, 'commission_policies_unavailable'])
  assertEquals(s.mock.calls.every((c) => c.path === '/v1/campaigns'), true)
})

Deno.test('catalog: bad "what" -> 400', async () => {
  const s = setup()
  assertEquals((await s.post(catalog(s.deps), { what: 'all' })).status, 400)
})
