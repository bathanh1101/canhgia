import { getActivation, saveActivation } from '../../lib/activation-store'
import { expectOk } from '../../lib/edge-client'
import { canInject, findMerchant, pageKind } from '../../lib/merchant-page-detectors'
import type { PageInfo, PopupData } from '../../lib/messages'
import { cachedRates } from '../../lib/rates-cache'
import type { Activation, MerchantRate, RecentOrder } from '../../lib/types'
import { parseCompare, parseCreateLink, parseResolve } from '../../lib/validators'
import { edgePost, getToken, supabase } from './supabase'

export const loadRates = (): Promise<MerchantRate[]> =>
  cachedRates(async () => {
    const { data, error } = await supabase.rpc('get_merchant_rates')
    if (error) throw new Error(error.message)
    return data
  })

async function rpc(fn: string, args: Record<string, unknown>): Promise<unknown> {
  const { data, error } = await supabase.rpc(fn, args)
  if (error) throw new Error(error.message)
  return data
}

export async function pageInfo(url: string): Promise<PageInfo> {
  const [rates, token] = await Promise.all([loadRates(), getToken()])
  const merchant = findMerchant(url, rates)
  const info: PageInfo = { loggedIn: !!token, rates, merchant, activation: null, resolve: null, compare: [], history: [] }
  if (!merchant) return info
  info.activation = await getActivation(merchant.merchant_id)
  // resolve/compare only where the bar can render them; failures degrade to the plain rate bar
  if (token && canInject(merchant) && pageKind(merchant.merchant_id, url) === 'product') {
    try {
      info.resolve = parseResolve(expectOk(await edgePost('resolve-url', { url }, true)))
      const g = info.resolve.offer?.product_group_id
      if (g) {
        info.compare = parseCompare(await rpc('get_compare', { p_group_id: g }))
        const h = (await rpc('get_price_history', { p_group_id: g, p_days: 90 })) as { day: string; min_price_vnd: number }[] | null
        info.history = (h ?? []).map((p) => ({ day: String(p.day), min_price_vnd: Number(p.min_price_vnd) }))
      }
    } catch (e) {
      console.warn('canhgia: page info degraded', e)
    }
  }
  return info
}

export async function activate(tabId: number, merchantId: string, url?: string, newTab = false): Promise<Activation> {
  const link = parseCreateLink(expectOk(await edgePost('create-link', { merchant_id: merchantId, source: 'extension', ...(url ? { url } : {}) }, true)))
  const a = await saveActivation(merchantId, link.activation_hours)
  if (newTab) await chrome.tabs.create({ url: link.aff_link })
  else await chrome.tabs.update(tabId, { url: link.aff_link })
  return a
}

export async function popupData(tabUrl: string): Promise<PopupData> {
  const [rates, { data: s }] = await Promise.all([loadRates(), supabase.auth.getSession()])
  const merchant = findMerchant(tabUrl, rates)
  const activation = merchant ? await getActivation(merchant.merchant_id) : null
  const uid = s.session?.user.id
  if (!uid) return { loggedIn: false, user: null, orders: [], merchant, activation }
  const [p, w, o] = await Promise.all([
    supabase.from('profiles').select('display_name, vip_tier_code').eq('id', uid).maybeSingle(),
    supabase.from('wallets').select('available_vnd, pending_vnd').eq('user_id', uid).maybeSingle(),
    supabase.from('orders').select('merchant_id, product_name, user_cashback_vnd, credit_state, order_time').order('created_at', { ascending: false }).limit(3),
  ])
  const err = p.error ?? w.error ?? o.error
  if (err) throw new Error(err.message)
  return {
    loggedIn: true,
    user: {
      name: (p.data?.display_name as string | null) ?? s.session?.user.email ?? 'Bạn',
      vipCode: (p.data?.vip_tier_code as string | null) ?? null,
      availableVnd: Number(w.data?.available_vnd ?? 0),
      pendingVnd: Number(w.data?.pending_vnd ?? 0),
    },
    orders: (o.data ?? []) as RecentOrder[],
    merchant,
    activation,
  }
}
