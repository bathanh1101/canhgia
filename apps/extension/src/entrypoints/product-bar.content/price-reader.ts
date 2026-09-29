// Reads ONLY the price text of the page the user is viewing (no network, no crawling). Every failure returns null.
const ORIGINAL_SELECTORS: Record<string, string[]> = {
  shopee: ['[class*="original-price"]', '.Y3DvsN', '.WTFwws'],
  lazada: ['.pdp-price_type_deleted', '[class*="price_type_deleted"]'],
  tiki: ['.product-price__original-price', '[class*="original-price"]'],
  tiktok_shop: ['[class*="original-price"]', '[class*="OriginalPrice"]'],
}

export function parseVnd(text: string | null | undefined): number | null {
  const digits = (text ?? '').replace(/[^\d]/g, '')
  const n = Number(digits)
  return digits.length >= 4 && Number.isSafeInteger(n) ? n : null
}

function jsonLdPrice(doc: Document): number | null {
  for (const s of doc.querySelectorAll('script[type="application/ld+json"]')) {
    try {
      const walk = (x: unknown): number | null => {
        if (Array.isArray(x)) return x.map(walk).find((v) => v !== null) ?? null
        if (typeof x !== 'object' || x === null) return null
        const o = x as Record<string, unknown>
        const offers = o.offers as Record<string, unknown> | Record<string, unknown>[] | undefined
        const first = Array.isArray(offers) ? offers[0] : offers
        const p = Number(first?.price ?? first?.lowPrice)
        return Number.isFinite(p) && p > 0 ? Math.round(p) : walk(o['@graph'])
      }
      const v = walk(JSON.parse(s.textContent ?? ''))
      if (v) return v
    } catch {
      /* malformed JSON-LD on the merchant page: try the next block */
    }
  }
  return null
}

export function readPrices(doc: Document, merchantId: string): { current: number | null; original: number | null } {
  try {
    const meta = parseVnd(doc.querySelector('meta[property="product:price:amount"]')?.getAttribute('content'))
    const current = jsonLdPrice(doc) ?? meta
    let original: number | null = null
    for (const sel of ORIGINAL_SELECTORS[merchantId] ?? []) {
      original = parseVnd(doc.querySelector(sel)?.textContent)
      if (original) break
    }
    return { current, original }
  } catch {
    return { current: null, original: null }
  }
}
