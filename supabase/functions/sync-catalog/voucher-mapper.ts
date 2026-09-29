// AT offers_informations row -> upsert_vouchers row. `link` (merchant URL) is stored, never `aff_link`
// (that one carries AccessTrade's generic publisher id, not ours; attribution goes through create-link).
type Row = Record<string, unknown>
const s = (v: unknown) => (typeof v === 'string' && v.trim() ? v.trim() : null)
// end_time is a date (YYYY-MM-DD): valid through the end of that day in ICT
const at = (v: unknown, time: string) => (s(v) && /^\d{4}-\d{2}-\d{2}$/.test(String(v)) ? `${v}T${time}+07:00` : null)

export function mapVoucher(merchantId: string, r: Row): Row | null {
  const id = s(r.id)
  if (!id) return null
  const coupon = (Array.isArray(r.coupons) ? r.coupons[0] : null) as Row | null
  return {
    merchant_id: merchantId,
    external_id: id,
    code: s(coupon?.coupon_code),
    title: s(r.name),
    description: s(r.content),
    discount_text: s(coupon?.coupon_desc),
    url: s(r.link),
    starts_at: at(r.start_time, '00:00:00'),
    ends_at: at(r.end_time, '23:59:59'),
  }
}
