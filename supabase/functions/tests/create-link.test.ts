import { assertEquals } from '@std/assert'
import { makeHandler } from '../create-link/handler.ts'
import { createAtClient } from '../_shared/accesstrade-client.ts'
import type { MerchantRow } from '../_shared/merchant-url-parser.ts'
import { fakeBucket, makeFakeDb } from './fake-db.ts'
import { startMock } from './mock-accesstrade.ts'

type Row = Record<string, unknown>
const M = (id: string, domains: string[], link_api: MerchantRow['link_api']): MerchantRow => ({
  id,
  domains,
  at_campaign_id: `camp-${id}`,
  link_api,
  datafeed_enabled: true,
  activation_hours: 168,
})
const MERCHANTS = [
  M('shopee', ['shopee.vn'], 'product_link'),
  M('tiktok_shop', ['tiktok.com'], 'tiktok_shop'),
  M('agoda', ['agoda.com'], 'campaign_default'),
]
const SHOPEE = 'https://shopee.vn/Ao-i.1.2'

function setup(o: { bucket?: boolean; createClickError?: string } = {}) {
  const mock = startMock()
  const clicks: Row[] = []
  const clock = () => 0
  const take = fakeBucket(Date.now)
  const admin = makeFakeDb({
    handlers: {
      at_rate_limit_take: (a) => (o.bucket === false ? false : take(a)),
      create_click: (a) => {
        if (o.createClickError) throw new Error(o.createClickError)
        const hit = clicks.find((c) => c.aff_link && c.resolved === a.p_resolved_url && c.merchant === a.p_merchant_id)
        if (hit) return [{ click_id: hit.id, utm_content: hit.utm, aff_link: hit.aff_link, short_link: hit.short_link }]
        const id = clicks.length + 1
        clicks.push({
          id,
          utm: `u1c${id}`,
          resolved: a.p_resolved_url,
          merchant: a.p_merchant_id,
          aff_link: null,
          status: 'pending',
          device: a.p_device_hash,
          offer: a.p_offer_id,
        })
        return [{ click_id: id, utm_content: `u1c${id}`, aff_link: null, short_link: null }]
      },
      set_click_link: (a) => {
        const c = clicks.find((x) => x.id === a.p_click_id)!
        Object.assign(c, { aff_link: a.p_aff_link, short_link: a.p_short_link, status: a.p_aff_link ? 'ok' : 'failed' })
        return null
      },
    },
  })
  const userDb = makeFakeDb({
    tables: {
      offers: [{
        id: 7,
        merchant_id: 'shopee',
        external_product_id: '1.2',
        name: 'Ao',
        image_url: 'i.jpg',
        price: 100000,
        product_group_id: null,
        cashback_eligible: true,
        category_key: 'fashion',
      }],
      profiles: [{ id: 'u1', vip_tier_code: 'silver' }],
    },
    handlers: { estimate_cashback: () => [{ base_rate_bps: 100, vip_rate_bps: 20, user_cashback_vnd: 1200 }] },
  })
  const at = createAtClient({ db: admin, baseUrl: mock.url, token: 'tok', now: clock, sleep: () => Promise.resolve() })
  const h = makeHandler({
    user: () => Promise.resolve({ id: 'u1', client: userDb }),
    db: admin,
    at,
    merchants: () => Promise.resolve(MERCHANTS),
  })
  const call = async (body: Row) => {
    const res = await h(new Request('http://x/', { method: 'POST', body: JSON.stringify(body) }))
    return { status: res.status, body: await res.json() as Row }
  }
  return { mock, clicks, admin, call }
}

Deno.test('product_link: sends campaign/url/utm/sub1, stores link, returns estimate', async () => {
  const s = setup()
  const r = await s.call({ merchant_id: 'shopee', url: SHOPEE, source: 'app', device_id: 'device-12345' })
  assertEquals(r.status, 200)
  assertEquals(r.body, {
    click_id: 1,
    aff_link: 'https://go.example/deep_link/X',
    short_link: 'https://shorten.example/X',
    merchant_id: 'shopee',
    activation_hours: 168,
    estimate: { base_rate_bps: 100, vip_rate_bps: 20, cashback_vnd: 1200 },
  })
  assertEquals(s.mock.calls[0].path, '/v1/product_link/create')
  assertEquals(s.mock.calls[0].body, {
    campaign_id: 'camp-shopee',
    urls: [SHOPEE],
    utm_source: 'canhgia',
    utm_medium: 'app',
    utm_content: 'u1c1',
    sub1: '1',
  })
  assertEquals([s.clicks[0].status, s.clicks[0].offer, String(s.clicks[0].device).length], ['ok', 7, 64])
  await s.mock.close()
})

Deno.test('dedupe hit returns the stored link without calling AccessTrade', async () => {
  const s = setup()
  await s.call({ merchant_id: 'shopee', url: SHOPEE, source: 'app' })
  const again = await s.call({ merchant_id: 'shopee', url: SHOPEE, source: 'extension' })
  assertEquals([again.status, again.body.click_id, s.mock.calls.length], [200, 1, 1])
  await s.mock.close()
})

Deno.test('tiktok_shop uses the v2 create_link endpoint', async () => {
  const s = setup()
  const r = await s.call({ merchant_id: 'tiktok_shop', url: 'https://www.tiktok.com/view/product/99', source: 'app' })
  assertEquals([r.status, r.body.aff_link, r.body.short_link], [200, 'https://go.example/tt/X', 'https://shorten.example/tt'])
  assertEquals(s.mock.calls[0].path, '/v2/tiktokshop_product_feeds/create_link')
  assertEquals(s.mock.calls[0].body, {
    product_url: 'https://www.tiktok.com/view/product/99',
    utm_source: 'canhgia',
    utm_content: 'u1c1',
    sub1: '1',
  })
  await s.mock.close()
})

Deno.test('campaign_default omits urls and needs no url from the client', async () => {
  const s = setup()
  const r = await s.call({ merchant_id: 'agoda', source: 'app' })
  assertEquals(r.status, 200)
  const body = s.mock.calls[0].body as Row
  assertEquals(['urls' in body, body.campaign_id], [false, 'camp-agoda'])
  await s.mock.close()
})

Deno.test('AccessTrade refuses the link -> 422 merchant_unavailable and click marked failed', async () => {
  const s = setup()
  s.mock.state.linkFail = true
  const r = await s.call({ merchant_id: 'shopee', url: SHOPEE, source: 'app' })
  assertEquals([r.status, r.body.error, s.clicks[0].status, s.clicks[0].aff_link], [422, 'merchant_unavailable', 'failed', null])
  await s.mock.close()
})

Deno.test('AccessTrade 5xx is retried once, then succeeds', async () => {
  const s = setup()
  s.mock.state.fail = { path: '/v1/product_link/create', onCall: 1, status: 503 }
  const r = await s.call({ merchant_id: 'shopee', url: SHOPEE, source: 'app' })
  assertEquals([r.status, s.mock.calls.length], [200, 2])
  await s.mock.close()
})

Deno.test('empty product_link bucket -> 429 rate_limited, no AT call, click failed', async () => {
  const s = setup({ bucket: false })
  const r = await s.call({ merchant_id: 'shopee', url: SHOPEE, source: 'app' })
  assertEquals([r.status, r.body.error, s.mock.calls.length, s.clicks[0].status], [429, 'rate_limited', 0, 'failed'])
  await s.mock.close()
})

Deno.test('SQL vocabulary errors map to HTTP: account_locked 403, rate_limited 429', async () => {
  for (const [code, status] of [['account_locked', 403], ['rate_limited', 429]] as const) {
    const s = setup({ createClickError: code })
    const r = await s.call({ merchant_id: 'shopee', url: SHOPEE, source: 'app' })
    assertEquals([r.status, r.body.error, s.mock.calls.length], [status, code, 0])
    await s.mock.close()
  }
})

Deno.test('input validation', async () => {
  const s = setup()
  assertEquals((await s.call({ merchant_id: 'nope', url: SHOPEE, source: 'app' })).body.error, 'merchant_unavailable')
  assertEquals((await s.call({ merchant_id: 'shopee', url: 'https://tiki.vn/a-p1.html', source: 'app' })).body.error, 'unsupported_url')
  assertEquals((await s.call({ merchant_id: 'shopee', url: SHOPEE, source: 'web' })).status, 400)
  assertEquals((await s.call({ merchant_id: 'shopee', source: 'app' })).status, 400) // product_link needs url
  assertEquals((await s.call({ source: 'app' })).status, 400)
  assertEquals(s.clicks.length, 0)
  await s.mock.close()
})
