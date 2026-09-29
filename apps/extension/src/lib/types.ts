// Shapes returned by the backend (docs/backend-contracts.md). Hand-typed: only fields the extension reads.
export interface MerchantRate {
  merchant_id: string
  name: string
  badge_letter: string
  domains: string[]
  max_user_rate_bps: number
  datafeed_enabled: boolean
  extension_enabled: boolean
  activation_hours: number
}

export interface OfferInfo {
  id: number
  name: string
  price_vnd: number | null
  product_group_id: number | null
  cashback_eligible: boolean
}

export interface ResolveResult {
  merchant_id: string
  offer: OfferInfo | null
  estimate: { base_rate_bps: number; vip_rate_bps: number; cashback_vnd: number | null } | null
}

export interface CreateLinkResult {
  aff_link: string
  activation_hours: number
}

export interface CompareRow {
  offer_id: number
  merchant_id: string
  shop_name: string | null
  url: string | null
  price_vnd: number
  effective_price_vnd: number
  est_cashback_vnd: number
  cashback_eligible: boolean
}

export interface PricePoint {
  day: string
  min_price_vnd: number
}

export interface Activation {
  merchantId: string
  expiresAt: number
}

export interface RecentOrder {
  merchant_id: string
  product_name: string | null
  user_cashback_vnd: number
  credit_state: string
  order_time: string | null
}

export interface PopupUser {
  name: string
  vipCode: string | null
  availableVnd: number
  pendingVnd: number
}
