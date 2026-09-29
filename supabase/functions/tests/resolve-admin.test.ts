import { assertEquals } from '@std/assert'
import { makeHandler as resolve } from '../resolve-url/handler.ts'
import { makeHandler as lookup } from '../admin-at-lookup/handler.ts'
import { createAtClient } from '../_shared/accesstrade-client.ts'
import type { MerchantRow } from '../_shared/merchant-url-parser.ts'
import { fakeBucket, makeFakeDb } from './fake-db.ts'
import { makeConversions, startMock } from './mock-accesstrade.ts'

type Row = Record<string, unknown>
const MERCHANTS: MerchantRow[] = [{
  id: 'shopee',
  domains: ['shopee.vn'],
  at_campaign_id: 'shopee',
  link_api: 'product_link',
  datafeed_enabled: true,
  activation_hours: 168,
}]
const post = async (h: (r: Request) => Promise<Response>, body: Row) => {
  const res = await h(new Request('http://x/', { method: 'POST', body: JSON.stringify(body) }))
  return { status: res.status, body: await res.json() as Row }
}

Deno.test('resolve-url: known offer + estimate; unknown product still resolves; foreign host 422', async () => {
  const client = makeFakeDb({
    tables: {
      offers: [{
        id: 7,
        merchant_id: 'shopee',
        external_product_id: '1.2',
        name: 'Ao',
        image_url: 'i.jpg',
        price: 100000,
        product_group_id: 3,
        cashback_eligible: true,
        category_key: 'c',
      }],
      profiles: [{ id: 'u1', vip_tier_code: null }],
    },
    handlers: { estimate_cashback: (a) => [{ base_rate_bps: 120, vip_rate_bps: 0, user_cashback_vnd: Number(a.p_order_value) / 100 }] },
  })
  const h = resolve({ user: () => Promise.resolve({ id: 'u1', client }), merchants: () => Promise.resolve(MERCHANTS) })
  const hit = await post(h, { url: 'https://shopee.vn/Ao-i.1.2' })
  assertEquals(hit.body, {
    merchant_id: 'shopee',
    resolved_url: 'https://shopee.vn/Ao-i.1.2',
    datafeed_enabled: true,
    offer: { id: 7, name: 'Ao', image: 'i.jpg', price_vnd: 100000, product_group_id: 3, cashback_eligible: true },
    estimate: { base_rate_bps: 120, vip_rate_bps: 0, cashback_vnd: 1000 },
  })
  const miss = await post(h, { url: 'https://shopee.vn/Other-i.9.9' })
  assertEquals([miss.status, 'offer' in miss.body, (miss.body.estimate as Row).cashback_vnd], [200, false, undefined])
  assertEquals(await post(h, { url: 'https://evil.example/x' }), { status: 422, body: { error: 'unsupported_url' } })
  assertEquals((await post(h, {})).status, 400)
})

function lookupSetup(isAdmin: boolean, bucket = true) {
  const mock = startMock()
  const take = fakeBucket(Date.now)
  const db = makeFakeDb({
    handlers: { at_rate_limit_take: (a) => (bucket ? take(a) : false) },
    tables: { clicks: [{ id: 2, user_id: 'buyer', utm_content: 'u1c2' }, { id: 3, user_id: 'x', utm_content: 'u1c3' }] },
  })
  const admin = makeFakeDb({ handlers: { is_admin: () => isAdmin } })
  const at = createAtClient({ db, baseUrl: mock.url, token: 't', sleep: () => Promise.resolve() })
  mock.state.conversions = makeConversions(3)
  return {
    mock,
    db,
    h: lookup({ user: () => Promise.resolve({ id: 'a', client: admin }), db, at, merchants: () => Promise.resolve(MERCHANTS) }),
  }
}

Deno.test('admin-at-lookup: non-admin -> 403 before any AT/service-role use', async () => {
  const s = lookupSetup(false)
  assertEquals(await post(s.h, { merchant_id: 'shopee', order_code: 'ORD2', purchased_on: '2026-09-29' }), {
    status: 403,
    body: { error: 'forbidden' },
  })
  assertEquals([s.mock.calls.length, s.db.calls.length], [0, 0])
  await s.mock.close()
})

Deno.test('admin-at-lookup: matches normalized code within +-3 days and returns the user click', async () => {
  const s = lookupSetup(true)
  const r = await post(s.h, { merchant_id: 'shopee', order_code: 'ord-2 ', purchased_on: '2026-09-29' })
  assertEquals(r.status, 200)
  assertEquals((r.body.rows as Row[]).map((x) => x.conversion_id), [2])
  assertEquals((r.body.clicks as Row[]).map((c) => c.user_id), ['buyer'])
  assertEquals([s.mock.calls[0].params.since, s.mock.calls[0].params.until], ['2026-09-26T00:00:00Z', '2026-10-02T23:59:59Z'])
  await s.mock.close()
})

Deno.test('admin-at-lookup: empty bucket -> 429; bad date -> 400', async () => {
  const s = lookupSetup(true, false)
  assertEquals((await post(s.h, { merchant_id: 'shopee', order_code: 'ORD2', purchased_on: '2026-09-29' })).body.error, 'rate_limited')
  assertEquals((await post(s.h, { merchant_id: 'shopee', order_code: 'ORD2', purchased_on: '29/09/2026' })).status, 400)
  await s.mock.close()
})
