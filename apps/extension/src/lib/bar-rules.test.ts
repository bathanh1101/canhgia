import { describe, expect, it } from 'vitest'
import { alternatives, barView, cheaperElsewhere, fakeDiscount } from './bar-rules'
import type { CompareRow, PricePoint } from './types'

const hist = (prices: number[]): PricePoint[] => prices.map((p, i) => ({ day: `2026-09-${String(i + 1).padStart(2, '0')}`, min_price_vnd: p }))
const row = (offer_id: number, merchant_id: string, eff: number, eligible = true): CompareRow =>
  ({ offer_id, merchant_id, shop_name: null, url: null, price_vnd: eff, effective_price_vnd: eff, est_cashback_vnd: 0, cashback_eligible: eligible })

describe('fakeDiscount', () => {
  const flat = hist([100, 100, 100, 100, 100, 100, 100])
  it('flags a shown discount when price is not below the 90-day median', () => {
    expect(fakeDiscount(100, 150, flat)).toEqual({ discountPct: 33, medianVnd: 100 })
    expect(fakeDiscount(120, 150, flat)).not.toBeNull()
  })
  it('does not flag a real discount', () => expect(fakeDiscount(80, 150, flat)).toBeNull())
  it('needs a shown discount and enough history', () => {
    expect(fakeDiscount(100, null, flat)).toBeNull()
    expect(fakeDiscount(100, 100, flat)).toBeNull()
    expect(fakeDiscount(100, 150, hist([100, 100]))).toBeNull()
    expect(fakeDiscount(null, 150, flat)).toBeNull()
  })
  it('uses the median (robust to one spike)', () => expect(fakeDiscount(90, 150, hist([100, 100, 100, 100, 100, 100, 9999]))).toBeNull())
})

describe('cheaperElsewhere / alternatives', () => {
  const rows = [row(1, 'shopee', 1000), row(2, 'lazada', 900), row(3, 'tiki', 950, false)]
  it('reports the saving vs the best other merchant', () => expect(cheaperElsewhere(rows, 1)).toEqual({ merchantId: 'lazada', savingVnd: 100 }))
  it('null when current is cheapest or unknown', () => {
    expect(cheaperElsewhere(rows, 2)).toBeNull()
    expect(cheaperElsewhere(rows, 99)).toBeNull()
    expect(cheaperElsewhere([], null)).toBeNull()
  })
  it('alternatives keep only eligible other offers', () => expect(alternatives(rows, 1).map((r) => r.offer_id)).toEqual([2]))
})

describe('barView priority', () => {
  const base = { eligible: true, activation: null, fake: null, cheaper: null, alternatives: [], maxRateBps: 700 }
  const fake = { discountPct: 35, medianVnd: 100 }
  const act = { merchantId: 'shopee', expiresAt: 9 }
  it('ineligible offer -> state 4 even when activated', () => expect(barView({ ...base, eligible: false, activation: act }).kind).toBe('not_eligible'))
  it('activated beats fake discount', () => expect(barView({ ...base, activation: act, fake }).kind).toBe('active'))
  it('fake discount beats default', () => expect(barView({ ...base, fake }).kind).toBe('fake_discount'))
  it('default is inactive', () => expect(barView(base).kind).toBe('inactive'))
})
