import type { MerchantRate } from './types'

// Host matching uses get_merchant_rates().domains (SSOT); only the page-shape patterns live here
// (copied from supabase/functions/_shared/merchant-url-parser.ts; tests share one fixture list).
interface Shapes {
  product: RegExp[]
  search: RegExp[]
  checkout: RegExp[]
}

const SHAPES: Record<string, Shapes> = {
  shopee: { product: [/-i\.\d+\.\d+/, /\/product\/\d+\/\d+/], search: [/^\/search/], checkout: [/^\/cart/, /^\/checkout/] },
  lazada: { product: [/-i\d+(?:-s\d+)?\.html/], search: [/^\/catalog/, /^\/tag\//], checkout: [/^\/cart/, /^\/checkout/] },
  tiki: { product: [/-p\d+\.html/], search: [/^\/search/], checkout: [/^\/checkout/] },
  tiktok_shop: { product: [/\/product\/\d+/], search: [/\/shop\/s\//, /^\/search/], checkout: [/\/checkout/] },
}

export function hostMatches(host: string, domain: string): boolean {
  const h = host.toLowerCase(), d = domain.toLowerCase()
  return h === d || h.endsWith(`.${d}`)
}

function parse(url: string): URL | null {
  try {
    const u = new URL(url)
    return u.protocol === 'https:' || u.protocol === 'http:' ? u : null
  } catch {
    return null
  }
}

export function findMerchant(url: string, rates: MerchantRate[]): MerchantRate | null {
  const u = parse(url)
  return u ? rates.find((m) => m.domains.some((d) => hostMatches(u.hostname, d))) ?? null : null
}

export type PageKind = 'product' | 'search' | 'checkout' | 'other'

export function pageKind(merchantId: string, url: string): PageKind {
  const u = parse(url)
  const s = SHAPES[merchantId]
  if (!u || !s) return 'other'
  const hit = (rs: RegExp[]) => rs.some((r) => r.test(u.pathname))
  if (hit(s.checkout)) return 'checkout'
  if (hit(s.product)) return 'product'
  if (hit(s.search)) return 'search'
  return 'other'
}

/** Bar/labels are injected only where the merchant flag allows it and a page shape exists for it. */
export function canInject(m: MerchantRate | null): m is MerchantRate {
  return !!m && m.extension_enabled && m.merchant_id in SHAPES
}
