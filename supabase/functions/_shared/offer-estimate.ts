// Offer lookup + cashback estimate shared by resolve-url and create-link. Cashback math stays in SQL (02b estimate_cashback).
import type { Db } from './supabase-admin-client.ts'

const REF_VALUE_VND = 1_000_000 // rates are relative to order value; used when no offer price is known

export interface OfferOut {
  id: number
  name: string
  image: string | null
  price_vnd: number
  product_group_id: number | null
  cashback_eligible: boolean
}
export interface EstimateOut {
  base_rate_bps: number
  vip_rate_bps: number
  cashback_vnd?: number
}

export async function findOffer(client: Db, merchantId: string, externalId: string | null) {
  if (!externalId) return null
  const { data, error } = await client.from('offers')
    .select('id,name,image_url,price,product_group_id,cashback_eligible,category_key')
    .eq('merchant_id', merchantId).eq('external_product_id', externalId).maybeSingle()
  if (error) throw new Error(`offers lookup: ${error.message}`)
  if (!data) return null
  const offer: OfferOut = {
    id: data.id,
    name: data.name,
    image: data.image_url,
    price_vnd: Number(data.price),
    product_group_id: data.product_group_id,
    cashback_eligible: data.cashback_eligible,
  }
  return { offer, category: data.category_key as string | null }
}

// null when estimate_cashback is unavailable/fails (logged); callers still return the link.
export async function estimateFor(
  client: Db,
  uid: string,
  merchantId: string,
  found: { offer: OfferOut; category: string | null } | null,
): Promise<EstimateOut | null> {
  const { data: prof } = await client.from('profiles').select('vip_tier_code').eq('id', uid).maybeSingle()
  const value = found?.offer.price_vnd ?? null
  const { data, error } = await client.rpc('estimate_cashback', {
    p_merchant_id: merchantId,
    p_category_key: found?.category ?? null,
    p_order_value: value ?? REF_VALUE_VND,
    p_tier_code: prof?.vip_tier_code ?? null,
  })
  const row = (Array.isArray(data) ? data[0] : data) as
    | { base_rate_bps: number; vip_rate_bps: number; user_cashback_vnd: number }
    | undefined
  if (error || !row) {
    console.error('estimate_cashback', error?.message)
    return null
  }
  return {
    base_rate_bps: row.base_rate_bps,
    vip_rate_bps: row.vip_rate_bps,
    ...(value ? { cashback_vnd: Number(row.user_cashback_vnd) } : {}),
  }
}
