import type { CompareRow, CreateLinkResult, MerchantRate, ResolveResult } from './types'

type Obj = Record<string, unknown>
const isObj = (x: unknown): x is Obj => typeof x === 'object' && x !== null
const num = (x: unknown): number | null => (typeof x === 'number' && Number.isFinite(x) ? x : typeof x === 'string' && x !== '' && Number.isFinite(Number(x)) ? Number(x) : null)

export function parseRates(x: unknown): MerchantRate[] {
  if (!Array.isArray(x)) throw new Error('rates: not an array')
  return x.filter(isObj).flatMap((r) => {
    if (typeof r.merchant_id !== 'string' || typeof r.name !== 'string' || !Array.isArray(r.domains)) return []
    return [{
      merchant_id: r.merchant_id,
      name: r.name,
      badge_letter: typeof r.badge_letter === 'string' ? r.badge_letter : r.name.slice(0, 1),
      domains: r.domains.filter((d): d is string => typeof d === 'string'),
      max_user_rate_bps: num(r.max_user_rate_bps) ?? 0,
      datafeed_enabled: r.datafeed_enabled === true,
      extension_enabled: r.extension_enabled === true,
      activation_hours: num(r.activation_hours) ?? 24,
    }]
  })
}

/** The affiliate link is navigated to, so it must be a https URL (blocks javascript:, data:, http:). */
export function parseCreateLink(x: unknown): CreateLinkResult {
  if (!isObj(x) || typeof x.aff_link !== 'string') throw new Error('create-link: missing aff_link')
  const u = new URL(x.aff_link)
  if (u.protocol !== 'https:') throw new Error('create-link: bad aff_link protocol')
  return { aff_link: u.toString(), activation_hours: num(x.activation_hours) ?? 24 }
}

export function parseResolve(x: unknown): ResolveResult {
  if (!isObj(x) || typeof x.merchant_id !== 'string') throw new Error('resolve-url: bad response')
  const o = isObj(x.offer) ? x.offer : null
  const e = isObj(x.estimate) ? x.estimate : null
  return {
    merchant_id: x.merchant_id,
    offer: o && num(o.id) !== null
      ? { id: num(o.id)!, name: String(o.name ?? ''), price_vnd: num(o.price_vnd), product_group_id: num(o.product_group_id), cashback_eligible: o.cashback_eligible !== false }
      : null,
    estimate: e ? { base_rate_bps: num(e.base_rate_bps) ?? 0, vip_rate_bps: num(e.vip_rate_bps) ?? 0, cashback_vnd: num(e.cashback_vnd) } : null,
  }
}

export function parseCompare(x: unknown): CompareRow[] {
  if (!Array.isArray(x)) return []
  return x.filter(isObj).flatMap((r) => {
    const id = num(r.offer_id), p = num(r.price_vnd), eff = num(r.effective_price_vnd)
    if (id === null || p === null || eff === null || typeof r.merchant_id !== 'string') return []
    return [{ offer_id: id, merchant_id: r.merchant_id, shop_name: typeof r.shop_name === 'string' ? r.shop_name : null, url: typeof r.url === 'string' ? r.url : null, price_vnd: p, effective_price_vnd: eff, est_cashback_vnd: num(r.est_cashback_vnd) ?? 0, cashback_eligible: r.cashback_eligible === true }]
  })
}

/** OAuth implicit redirect: https://<id>.chromiumapp.org/#access_token=..&refresh_token=.. */
export function parseAuthRedirect(url: string): { access_token: string; refresh_token: string } {
  const p = new URLSearchParams(new URL(url).hash.replace(/^#/, ''))
  const access_token = p.get('access_token'), refresh_token = p.get('refresh_token')
  if (!access_token || !refresh_token) throw new Error(p.get('error_description') ?? 'auth redirect without tokens')
  return { access_token, refresh_token }
}
