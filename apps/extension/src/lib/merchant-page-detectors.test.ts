import { describe, expect, it } from 'vitest'
import { canInject, findMerchant, pageKind } from './merchant-page-detectors'
import type { MerchantRate } from './types'

const mk = (id: string, domains: string[], ext = true): MerchantRate => ({ merchant_id: id, name: id, badge_letter: id[0]!, domains, max_user_rate_bps: 700, datafeed_enabled: false, extension_enabled: ext, activation_hours: 24 })
const RATES = [mk('shopee', ['shopee.vn']), mk('lazada', ['lazada.vn']), mk('tiki', ['tiki.vn']), mk('tiktok_shop', ['tiktok.com', 'shop.tiktok.com']), mk('agoda', ['agoda.com'], false)]

// one fixture list shared by product / search / checkout expectations
const CASES: [string, string, string][] = [
  ['shopee', 'https://shopee.vn/Tai-nghe-Sony-i.1234.5678', 'product'],
  ['shopee', 'https://shopee.vn/product/1234/5678', 'product'],
  ['shopee', 'https://shopee.vn/search?keyword=tai%20nghe', 'search'],
  ['shopee', 'https://shopee.vn/cart', 'checkout'],
  ['shopee', 'https://shopee.vn/', 'other'],
  ['lazada', 'https://www.lazada.vn/products/noi-chien-i123456-s789.html', 'product'],
  ['lazada', 'https://www.lazada.vn/catalog/?q=noi', 'search'],
  ['lazada', 'https://cart.lazada.vn/cart', 'checkout'],
  ['tiki', 'https://tiki.vn/sach-p12345.html', 'product'],
  ['tiki', 'https://tiki.vn/search?q=sach', 'search'],
  ['tiki', 'https://tiki.vn/checkout/payment', 'checkout'],
  ['tiktok_shop', 'https://www.tiktok.com/view/product/998877', 'product'],
  ['tiktok_shop', 'https://www.tiktok.com/@user/video/1', 'other'],
]

describe('pageKind', () => {
  it.each(CASES)('%s %s -> %s', (id, url, kind) => expect(pageKind(id, url)).toBe(kind))
  it('never throws on garbage or unknown merchants', () => {
    expect(pageKind('shopee', 'not a url')).toBe('other')
    expect(pageKind('shopee', 'javascript:alert(1)')).toBe('other')
    expect(pageKind('agoda', 'https://agoda.com/x-i.1.2')).toBe('other')
  })
})

describe('findMerchant', () => {
  it('matches domains and subdomains only', () => {
    expect(findMerchant('https://www.shopee.vn/a', RATES)?.merchant_id).toBe('shopee')
    expect(findMerchant('https://evilshopee.vn/a', RATES)).toBeNull()
    expect(findMerchant('https://shopee.vn.evil.com/a', RATES)).toBeNull()
    expect(findMerchant('', RATES)).toBeNull()
  })
  it('travel merchants are found (popup) but never injectable', () => {
    const m = findMerchant('https://www.agoda.com/hotel', RATES)
    expect(m?.merchant_id).toBe('agoda')
    expect(canInject(m)).toBe(false)
  })
  it('extension_enabled=false blocks injection even on a known shape', () => {
    expect(canInject(mk('shopee', ['shopee.vn'], false))).toBe(false)
    expect(canInject(RATES[0]!)).toBe(true)
  })
})
