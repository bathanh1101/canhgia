// Pasted-URL -> merchant + product id. Domains come from the merchants table (SSOT). Short-link expansion is SSRF-safe:
// https only, host allowlist re-checked on every hop, redirect:'manual', <= 5 hops, 3s per hop.
import type { Db } from './supabase-admin-client.ts'
export interface MerchantRow {
  id: string
  domains: string[]
  at_campaign_id: string | null
  link_api: 'product_link' | 'tiktok_shop' | 'campaign_default'
  datafeed_enabled: boolean
  activation_hours: number
}

export interface ParsedUrl {
  merchant: MerchantRow
  resolvedUrl: string
  externalProductId: string | null
}

export const SHORT_HOSTS = ['shp.ee', 's.shopee.vn', 's.lazada.vn', 'vt.tiktok.com']
const MAX_HOPS = 5

const hostIs = (host: string, d: string) => host === d || host.endsWith(`.${d}`)

export function findMerchant(host: string, merchants: MerchantRow[]): MerchantRow | null {
  return merchants.find((m) => m.domains.some((d) => hostIs(host, d.toLowerCase()))) ?? null
}

/** External product id per merchant URL shape; null when the URL is not a product page (or a travel merchant). */
export function extractProductId(url: string): string | null {
  let u: URL
  try {
    u = new URL(url)
  } catch {
    return null
  }
  const h = u.hostname.toLowerCase()
  const p = u.pathname
  let m: RegExpMatchArray | null
  if (hostIs(h, 'shopee.vn')) {
    m = p.match(/-i\.(\d+)\.(\d+)/) ?? p.match(/\/product\/(\d+)\/(\d+)/)
    return m ? `${m[1]}.${m[2]}` : null
  }
  if (hostIs(h, 'lazada.vn')) return p.match(/-i(\d+)(?:-s\d+)?\.html/)?.[1] ?? null
  if (hostIs(h, 'tiki.vn')) return p.match(/-p(\d+)\.html/)?.[1] ?? null
  if (hostIs(h, 'tiktok.com')) return p.match(/\/product\/(\d+)/)?.[1] ?? null
  return null
}

function safeUrl(raw: string, allowed: (host: string) => boolean): URL | null {
  let u: URL
  try {
    u = new URL(raw)
  } catch {
    return null
  }
  if (u.protocol !== 'https:' || u.username || u.password || (u.port && u.port !== '443')) return null
  const h = u.hostname.toLowerCase()
  if (h.includes(':') || /^\d+(\.\d+){3}$/.test(h)) return null // IP literals never allowed
  return allowed(h) ? u : null
}

export async function expandShortLink(
  start: URL,
  allowed: (host: string) => boolean,
  fetchFn: typeof fetch = fetch,
): Promise<URL | null> {
  let cur = start
  for (let hop = 0; hop < MAX_HOPS; hop++) {
    if (!SHORT_HOSTS.includes(cur.hostname.toLowerCase())) return cur // reached a real merchant page
    let res: Response
    try {
      res = await fetchFn(cur, { method: 'GET', redirect: 'manual', signal: AbortSignal.timeout(3000) })
    } catch {
      return null
    }
    await res.body?.cancel()
    const loc = res.status >= 300 && res.status < 400 ? res.headers.get('location') : null
    if (!loc) return null
    const next = safeUrl(new URL(loc, cur).toString(), allowed)
    if (!next) return null
    cur = next
  }
  return SHORT_HOSTS.includes(cur.hostname.toLowerCase()) ? null : cur
}

export async function parseMerchantUrl(
  raw: string,
  merchants: MerchantRow[],
  fetchFn: typeof fetch = fetch,
): Promise<ParsedUrl | null> {
  const allowed = (h: string) => SHORT_HOSTS.includes(h) || findMerchant(h, merchants) !== null
  const first = safeUrl(raw.trim(), allowed)
  if (!first) return null
  const final = await expandShortLink(first, allowed, fetchFn)
  if (!final) return null
  const merchant = findMerchant(final.hostname.toLowerCase(), merchants)
  if (!merchant) return null
  final.hash = ''
  return { merchant, resolvedUrl: final.toString(), externalProductId: extractProductId(final.toString()) }
}

export const MERCHANT_COLS = 'id,domains,at_campaign_id,link_api,datafeed_enabled,activation_hours'

export async function loadMerchants(db: Db): Promise<MerchantRow[]> {
  const { data, error } = await db.from('merchants').select(MERCHANT_COLS).eq('is_active', true)
  if (error) throw new Error(`merchants load: ${error.message}`)
  return data as MerchantRow[]
}
