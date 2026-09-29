import { assertEquals } from '@std/assert'
import { extractProductId, type MerchantRow, parseMerchantUrl } from '../_shared/merchant-url-parser.ts'

const m = (id: string, domains: string[], link_api: MerchantRow['link_api'] = 'product_link'): MerchantRow => ({
  id,
  domains,
  at_campaign_id: `c-${id}`,
  link_api,
  datafeed_enabled: true,
  activation_hours: 168,
})
const MERCHANTS = [
  m('shopee', ['shopee.vn', 'shp.ee']),
  m('lazada', ['lazada.vn']),
  m('tiki', ['tiki.vn']),
  m('tiktok_shop', ['tiktok.com'], 'tiktok_shop'),
  m('agoda', ['agoda.com'], 'campaign_default'),
  m('traveloka', ['traveloka.com'], 'campaign_default'),
  m('klook', ['klook.com'], 'campaign_default'),
]

const cases: [string, string, string | null][] = [
  ['shopee', 'https://shopee.vn/Ao-thun-nam-cotton-i.14346466.255489769', '14346466.255489769'],
  ['shopee', 'https://shopee.vn/product/14346466/255489769?sp_atk=abc', '14346466.255489769'],
  ['shopee', 'https://shopee.vn/Giay-Nike-Air-i.123.456?xptdk=1#frag', '123.456'],
  ['lazada', 'https://www.lazada.vn/products/ao-khoac-nam-i2345678901-s9876543210.html', '2345678901'],
  ['lazada', 'https://www.lazada.vn/products/tai-nghe-i100200300.html?spm=a2o4n', '100200300'],
  ['lazada', 'https://lazada.vn/products/x-i555.html', '555'],
  ['tiki', 'https://tiki.vn/binh-giu-nhiet-lock-lock-p123456789.html?spid=1', '123456789'],
  ['tiki', 'https://tiki.vn/sach-p74.html', '74'],
  ['tiki', 'https://tiki.vn/a-b-c-p9.html', '9'],
  ['tiktok_shop', 'https://www.tiktok.com/view/product/1729384756', '1729384756'],
  ['tiktok_shop', 'https://shop.tiktok.com/view/product/17293?x=1', '17293'],
  ['tiktok_shop', 'https://www.tiktok.com/@shop/product/8888', '8888'],
  ['agoda', 'https://www.agoda.com/vi-vn/hotel/da-nang.html', null],
  ['traveloka', 'https://www.traveloka.com/vi-vn/hotel/detail?spec=1', null],
  ['klook', 'https://www.klook.com/vi/activity/1234-tour/', null],
]
for (const [id, url, ext] of cases) {
  Deno.test(`parses ${id}: ${url.slice(0, 60)}`, async () => {
    const p = await parseMerchantUrl(url, MERCHANTS, () => {
      throw new Error('no network expected')
    })
    assertEquals([p?.merchant.id, p?.externalProductId], [id, ext])
    assertEquals(p?.resolvedUrl.includes('#'), false)
  })
}

Deno.test('extractProductId: non-product page and junk', () => {
  assertEquals(extractProductId('https://shopee.vn/m/ma-giam-gia'), null)
  assertEquals(extractProductId('not a url'), null)
})

// fetch stub: map of url -> next location
const redirects = (map: Record<string, string>): typeof fetch => (input) => {
  const loc = map[String(input)]
  return Promise.resolve(loc ? new Response(null, { status: 302, headers: { location: loc } }) : new Response('ok', { status: 200 }))
}

Deno.test('expands shp.ee and vt.tiktok.com short links', async () => {
  const f = redirects({
    'https://shp.ee/abc123': 'https://shopee.vn/Ao-i.1.2',
    'https://vt.tiktok.com/ZS8xyz/': 'https://www.tiktok.com/view/product/99?x=1',
  })
  assertEquals((await parseMerchantUrl('https://shp.ee/abc123', MERCHANTS, f))?.externalProductId, '1.2')
  const t = await parseMerchantUrl('https://vt.tiktok.com/ZS8xyz/', MERCHANTS, f)
  assertEquals([t?.merchant.id, t?.externalProductId], ['tiktok_shop', '99'])
})

Deno.test('follows multi-hop redirects through allowed hosts', async () => {
  const f = redirects({ 'https://shp.ee/a': 'https://s.shopee.vn/b', 'https://s.shopee.vn/b': 'https://shopee.vn/x-i.5.6' })
  assertEquals((await parseMerchantUrl('https://shp.ee/a', MERCHANTS, f))?.externalProductId, '5.6')
})

for (
  const [name, url, map] of [
    ['unknown host', 'https://evil.example/x-i.1.2', {}],
    ['http scheme', 'http://shopee.vn/x-i.1.2', {}],
    ['javascript scheme', 'javascript:alert(1)', {}],
    ['credentials in url', 'https://user:pw@shopee.vn/x-i.1.2', {}],
    ['non-standard port', 'https://shopee.vn:8443/x-i.1.2', {}],
    ['lookalike host', 'https://shopee.vn.evil.com/x-i.1.2', {}],
    ['redirect to link-local metadata IP (SSRF)', 'https://shp.ee/a', { 'https://shp.ee/a': 'https://169.254.169.254/latest/meta-data' }],
    ['redirect to http://localhost', 'https://shp.ee/a', { 'https://shp.ee/a': 'http://localhost:8080/admin' }],
    ['redirect to unlisted host', 'https://shp.ee/a', { 'https://shp.ee/a': 'https://evil.example/' }],
    ['redirect loop > 5 hops', 'https://shp.ee/a', {
      'https://shp.ee/a': 'https://s.shopee.vn/b',
      'https://s.shopee.vn/b': 'https://shp.ee/a',
    }],
    ['short link with no redirect', 'https://shp.ee/dead', {}],
  ] as [string, string, Record<string, string>][]
) {
  Deno.test(`rejects: ${name}`, async () => {
    assertEquals(await parseMerchantUrl(url, MERCHANTS, redirects(map)), null)
  })
}

Deno.test('rejects when fetch throws (timeout)', async () => {
  assertEquals(await parseMerchantUrl('https://shp.ee/a', MERCHANTS, () => Promise.reject(new DOMException('t', 'TimeoutError'))), null)
})
