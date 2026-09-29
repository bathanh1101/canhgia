import type { Activation, CompareRow, PricePoint } from './types'

export type BarView =
  | { kind: 'inactive'; cheaper: Cheaper | null }
  | { kind: 'active'; expiresAt: number; cheaper: Cheaper | null }
  | { kind: 'not_eligible'; alternatives: number; maxRateBps: number }
  | { kind: 'fake_discount'; fake: FakeDiscount }

export interface Cheaper {
  merchantId: string
  savingVnd: number
}
export interface FakeDiscount {
  discountPct: number
  medianVnd: number
}

function median(xs: number[]): number {
  const s = [...xs].sort((a, b) => a - b)
  const m = s.length >> 1
  return s.length % 2 ? s[m]! : (s[m - 1]! + s[m]!) / 2
}

/** Discount is displayed (original > current) but today's price is not below the 90-day median. Needs >= 7 days of history. */
export function fakeDiscount(current: number | null, original: number | null, history: PricePoint[]): FakeDiscount | null {
  if (!current || !original || original <= current || history.length < 7) return null
  const med = median(history.map((h) => h.min_price_vnd))
  if (current < med) return null
  return { discountPct: Math.round(((original - current) / original) * 100), medianVnd: med }
}

/** Cheapest effective price (price - cashback) among OTHER merchants, if it beats the current offer's. */
export function cheaperElsewhere(rows: CompareRow[], currentOfferId: number | null): Cheaper | null {
  const cur = rows.find((r) => r.offer_id === currentOfferId)
  if (!cur) return null
  const best = rows.filter((r) => r.merchant_id !== cur.merchant_id).sort((a, b) => a.effective_price_vnd - b.effective_price_vnd)[0]
  return best && best.effective_price_vnd < cur.effective_price_vnd
    ? { merchantId: best.merchant_id, savingVnd: cur.effective_price_vnd - best.effective_price_vnd }
    : null
}

export function alternatives(rows: CompareRow[], currentOfferId: number | null): CompareRow[] {
  return rows.filter((r) => r.offer_id !== currentOfferId && r.cashback_eligible)
}

/** State priority: not eligible > activated > fake discount > default. */
export function barView(i: {
  eligible: boolean
  activation: Activation | null
  fake: FakeDiscount | null
  cheaper: Cheaper | null
  alternatives: CompareRow[]
  maxRateBps: number
}): BarView {
  if (!i.eligible) return { kind: 'not_eligible', alternatives: i.alternatives.length, maxRateBps: i.maxRateBps }
  if (i.activation) return { kind: 'active', expiresAt: i.activation.expiresAt, cheaper: i.cheaper }
  if (i.fake) return { kind: 'fake_discount', fake: i.fake }
  return { kind: 'inactive', cheaper: i.cheaper }
}
