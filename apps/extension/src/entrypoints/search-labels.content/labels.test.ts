import { describe, expect, it } from 'vitest'
import { injectLabels } from './labels'
import { parserFor } from './parsers'
import { readPrices } from '../product-bar.content/price-reader'

const doc = (html: string) => new DOMParser().parseFromString(html, 'text/html')

describe('injectLabels', () => {
  const shopee = parserFor('shopee')!
  it('labels every card once (idempotent)', () => {
    const d = doc('<ul><li class="shopee-search-item-result__item">a</li><li class="shopee-search-item-result__item">b</li></ul>')
    expect(injectLabels(d, shopee, 700)).toBe(2)
    expect(injectLabels(d, shopee, 700)).toBe(0)
    expect([...d.querySelectorAll('[data-canhgia-label] span, span[data-canhgia-label]')].map((e) => e.textContent)).toContain('Hoàn đến 7%')
  })
  it('falls through to the next selector when the first misses', () => {
    const d = doc('<div><a href="/x-i.1.2">p</a></div>')
    expect(injectLabels(d, shopee, 750)).toBe(1)
    expect(d.body.textContent).toContain('Hoàn đến 7,5%')
  })
  it('unknown layout adds nothing and never throws', () => {
    expect(injectLabels(doc('<main>nothing here</main>'), shopee, 700)).toBe(0)
  })
  it.each(['shopee', 'lazada', 'tiki', 'tiktok_shop'])('%s has a parser that tolerates an empty page', (id) => {
    expect(parserFor(id)!.cards(doc(''))).toEqual([])
  })
})

describe('readPrices', () => {
  it('reads JSON-LD current price and an original-price node', () => {
    const d = doc('<script type="application/ld+json">{"@type":"Product","offers":{"price":"6490000"}}</script><div class="pdp-price_type_deleted">7.990.000đ</div>')
    expect(readPrices(d, 'lazada')).toEqual({ current: 6490000, original: 7990000 })
  })
  it('fails silent on junk', () => {
    expect(readPrices(doc('<script type="application/ld+json">{oops</script>'), 'shopee')).toEqual({ current: null, original: null })
  })
})
