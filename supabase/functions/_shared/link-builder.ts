// Creates an affiliate link per merchants.link_api. Throws AtError on transport problems, Error('link_rejected') on AT refusal.
import type { AtClient, AtRequest } from './accesstrade-client.ts'
import type { MerchantRow } from './merchant-url-parser.ts'

export interface LinkInput {
  resolvedUrl: string | null
  utmContent: string
  clickId: number
  source: string
}
export interface Link {
  aff_link: string
  short_link: string | null
}

const CALL: Pick<AtRequest, 'bucket' | 'retries' | 'timeoutMs'> = { bucket: 'product_link', retries: [500], timeoutMs: 4000 } // 1 retry, ~8s cap
const isUrl = (v: unknown): v is string => typeof v === 'string' && v.startsWith('https://')

export async function createAffLink(at: AtClient, m: MerchantRow, i: LinkInput): Promise<Link> {
  const utm = { utm_source: 'canhgia', utm_content: i.utmContent, sub1: String(i.clickId) }
  if (m.link_api === 'tiktok_shop') {
    // TikTok links made via the generic Product Link tab are NOT tracked; v2 create_link is the only valid path.
    if (!i.resolvedUrl) throw new Error('link_rejected: url required')
    const res = await at.post('/v2/tiktokshop_product_feeds/create_link', { ...CALL, body: { product_url: i.resolvedUrl, ...utm } }) as {
      status?: boolean
      data?: { aff_url?: unknown; aff_short_url?: unknown }
    }
    if (res?.status !== true || !isUrl(res.data?.aff_url)) throw new Error('link_rejected: tiktok')
    return { aff_link: res.data.aff_url, short_link: isUrl(res.data.aff_short_url) ? res.data.aff_short_url : null }
  }
  if (!m.at_campaign_id) throw new Error('link_rejected: no campaign')
  // campaign_default: `urls` omitted -> campaign landing link (AMBIGUOUS: unverified against live API)
  const body = {
    campaign_id: m.at_campaign_id,
    ...(m.link_api === 'product_link' ? { urls: [i.resolvedUrl] } : {}),
    utm_medium: i.source,
    ...utm,
  }
  if (m.link_api === 'product_link' && !i.resolvedUrl) throw new Error('link_rejected: url required')
  const res = await at.post('/v1/product_link/create', { ...CALL, body }) as {
    success?: boolean
    data?: { success_link?: { aff_link?: unknown; short_link?: unknown }[]; error_link?: unknown[]; suspend_url?: unknown[] }
  }
  const ok = res?.data?.success_link?.[0]
  if (res?.success !== true || !isUrl(ok?.aff_link) || res.data?.error_link?.length || res.data?.suspend_url?.length) {
    throw new Error('link_rejected: product_link')
  }
  return { aff_link: ok.aff_link, short_link: isUrl(ok.short_link) ? ok.short_link : null }
}
