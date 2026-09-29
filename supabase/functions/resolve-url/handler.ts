import { HttpError, json, readBody, str, type UserResolver, wrap } from '../_shared/request-guards.ts'
import { type MerchantRow, parseMerchantUrl } from '../_shared/merchant-url-parser.ts'
import { estimateFor, findOffer } from '../_shared/offer-estimate.ts'

export interface Deps {
  user: UserResolver
  merchants: () => Promise<MerchantRow[]>
  fetchFn?: typeof fetch
}

export function makeHandler(d: Deps) {
  return wrap(async (req) => {
    const user = await d.user(req)
    const url = str(await readBody(req), 'url')!
    const parsed = await parseMerchantUrl(url, await d.merchants(), d.fetchFn)
    if (!parsed) throw new HttpError(422, 'unsupported_url')
    const { merchant, resolvedUrl, externalProductId } = parsed
    const found = await findOffer(user.client, merchant.id, externalProductId)
    return json({
      merchant_id: merchant.id,
      resolved_url: resolvedUrl,
      ...(found ? { offer: found.offer } : {}),
      estimate: await estimateFor(user.client, user.id, merchant.id, found),
      datafeed_enabled: merchant.datafeed_enabled,
    })
  })
}
