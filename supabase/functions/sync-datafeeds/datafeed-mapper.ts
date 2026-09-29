// AT datafeed row -> upsert_offers row (02a contract). Product id parsed from the URL so it equals what resolve-url extracts.
import { extractProductId } from '../_shared/merchant-url-parser.ts'

type Row = Record<string, unknown>
const s = (v: unknown) => (typeof v === 'string' && v.trim() ? v.trim() : null)
const n = (v: unknown) => (typeof v === 'number' && Number.isFinite(v) && v >= 0 ? v : null)

/** null = row unusable (no id, name or price); caller counts it as skipped. list_price left null: AT `discount*` fields are ambiguous. */
export function mapFeedRow(r: Row): Row | null {
  const url = s(r.url)
  const ext = (url && extractProductId(url)) ?? s(r.product_id)
  const name = s(r.name)
  const price = n(r.price)
  if (!ext || !name || price === null) return null
  return {
    external_product_id: ext,
    sku: s(r.sku),
    brand: s(r.brand),
    name,
    url,
    image_url: s(r.image),
    category_key: s(r.cate),
    price,
    list_price: null,
    shop_name: s(r.shop_name),
    cashback_eligible: true,
  }
}
