import { HttpError, json, readBody, str, type UserResolver, wrap } from '../_shared/request-guards.ts'
import { type MerchantRow, parseMerchantUrl } from '../_shared/merchant-url-parser.ts'
import { type Db, rpc } from '../_shared/supabase-admin-client.ts'
import { type AtClient, AtError } from '../_shared/accesstrade-client.ts'
import { createAffLink } from '../_shared/link-builder.ts'
import { estimateFor, findOffer } from '../_shared/offer-estimate.ts'

export interface Deps {
  user: UserResolver
  db: Db
  at: AtClient
  merchants: () => Promise<MerchantRow[]>
  fetchFn?: typeof fetch
}

interface ClickRow {
  click_id: number
  utm_content: string
  aff_link: string | null
  short_link: string | null
}

async function sha256Hex(s: string): Promise<string> {
  const d = new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(s)))
  return Array.from(d, (b) => b.toString(16).padStart(2, '0')).join('')
}

export function makeHandler(d: Deps) {
  return wrap(async (req) => {
    const user = await d.user(req)
    const b = await readBody(req)
    const merchantId = str(b, 'merchant_id', 64)!
    const source = str(b, 'source', 16)!
    if (source !== 'app' && source !== 'extension') throw new HttpError(400, 'invalid_input', 'source')
    const url = str(b, 'url', 2048, true)
    const deviceId = str(b, 'device_id', 200, true)

    const merchants = await d.merchants()
    let merchant = merchants.find((m) => m.id === merchantId)
    if (!merchant) throw new HttpError(422, 'merchant_unavailable')
    let resolvedUrl: string | null = null
    let extId: string | null = null
    if (url) {
      const p = await parseMerchantUrl(url, merchants, d.fetchFn)
      if (!p || p.merchant.id !== merchant.id) throw new HttpError(422, 'unsupported_url')
      merchant = p.merchant
      resolvedUrl = p.resolvedUrl
      extId = p.externalProductId
    } else if (merchant.link_api !== 'campaign_default') {
      throw new HttpError(400, 'invalid_input', 'url')
    }
    const found = await findOffer(user.client, merchant.id, extId)

    const rows = await rpc<ClickRow[]>(d.db, 'create_click', {
      p_user_id: user.id,
      p_merchant_id: merchant.id,
      p_origin_url: url ?? null,
      p_resolved_url: resolvedUrl,
      p_offer_id: found?.offer.id ?? null,
      p_source: source,
      p_device_hash: deviceId ? await sha256Hex(deviceId) : null,
    }, true)
    const click = rows[0]
    if (!click) throw new Error('create_click returned no row')

    let aff = click.aff_link
    let short = click.short_link
    if (!aff) { // not a dedupe hit: one AT call, failure marks the click failed (not counted)
      try {
        ;({ aff_link: aff, short_link: short } = await createAffLink(d.at, merchant, {
          resolvedUrl,
          utmContent: click.utm_content,
          clickId: click.click_id,
          source,
        }))
      } catch (e) {
        await rpc(d.db, 'set_click_link', { p_click_id: click.click_id, p_aff_link: null, p_short_link: null })
        if (e instanceof AtError && e.kind === 'rate_limited') throw new HttpError(429, 'rate_limited')
        console.error('create-link failed', (e as Error).message)
        throw new HttpError(422, 'merchant_unavailable')
      }
      await rpc(d.db, 'set_click_link', { p_click_id: click.click_id, p_aff_link: aff, p_short_link: short })
    }
    return json({
      click_id: click.click_id,
      aff_link: aff,
      short_link: short,
      merchant_id: merchant.id,
      activation_hours: merchant.activation_hours,
      estimate: await estimateFor(user.client, user.id, merchant.id, found),
    })
  })
}
