import { describe, expect, it } from 'vitest'
import { chromeStorage } from './chrome-storage-adapter'
import { parseAuthRedirect, parseCompare, parseCreateLink, parseRates, parseResolve } from './validators'

describe('parseCreateLink', () => {
  it('accepts https links', () => expect(parseCreateLink({ aff_link: 'https://go.isclix.com/x?a=1', activation_hours: 168 })).toEqual({ aff_link: 'https://go.isclix.com/x?a=1', activation_hours: 168 }))
  it.each(['javascript:alert(1)', 'data:text/html,x', 'not a url'])('rejects %s', (l) => expect(() => parseCreateLink({ aff_link: l })).toThrow())
  it('rejects missing link', () => expect(() => parseCreateLink({})).toThrow())
})

describe('parseAuthRedirect', () => {
  it('reads tokens from the hash', () => expect(parseAuthRedirect('https://abc.chromiumapp.org/#access_token=a&refresh_token=r&x=1')).toEqual({ access_token: 'a', refresh_token: 'r' }))
  it('throws with the provider message when tokens are absent', () => expect(() => parseAuthRedirect('https://abc.chromiumapp.org/#error_description=denied')).toThrow('denied'))
})

describe('boundary parsers drop malformed rows instead of throwing', () => {
  it('rates', () => {
    const r = parseRates([{ merchant_id: 'shopee', name: 'Shopee', domains: ['shopee.vn'], max_user_rate_bps: 700, extension_enabled: true }, { nope: 1 }, null])
    expect(r).toHaveLength(1)
    expect(r[0]?.extension_enabled).toBe(true)
    expect(() => parseRates({})).toThrow()
  })
  it('compare (bigint strings ok)', () => expect(parseCompare([{ offer_id: '5', merchant_id: 'lazada', price_vnd: 10, effective_price_vnd: '9' }, { offer_id: 1 }])).toHaveLength(1))
  it('resolve', () => {
    expect(parseResolve({ merchant_id: 'shopee', offer: { id: 1, name: 'x', price_vnd: 5, product_group_id: 2, cashback_eligible: false }, estimate: null }).offer?.cashback_eligible).toBe(false)
    expect(() => parseResolve(null)).toThrow()
  })
})

describe('chromeStorage adapter', () => {
  it('round-trips and removes', async () => {
    expect(await chromeStorage.getItem('k')).toBeNull()
    await chromeStorage.setItem('k', 'v')
    expect(await chromeStorage.getItem('k')).toBe('v')
    await chromeStorage.removeItem('k')
    expect(await chromeStorage.getItem('k')).toBeNull()
  })
})
