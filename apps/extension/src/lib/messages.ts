import type { Activation, CompareRow, MerchantRate, PopupUser, PricePoint, RecentOrder, ResolveResult } from './types'

// content script / popup -> background. Tokens never cross this boundary.
export interface PageInfo {
  loggedIn: boolean
  rates: MerchantRate[]
  merchant: MerchantRate | null
  activation: Activation | null
  resolve: ResolveResult | null
  compare: CompareRow[]
  history: PricePoint[]
}

export interface PopupData {
  loggedIn: boolean
  user: PopupUser | null
  orders: RecentOrder[]
  merchant: MerchantRate | null
  activation: Activation | null
}

export interface QrInfo {
  payload: string
  expiresAt: number
}
export type QrPollReply = { state: 'pending' } | { state: 'expired' } | { state: 'approved' }

export interface Requests {
  pageInfo: { req: { url: string }; res: PageInfo }
  popupData: { req: { tabUrl: string }; res: PopupData }
  activate: { req: { tabId: number; merchantId: string; url?: string; newTab?: boolean }; res: Activation }
  signInGoogle: { req: Record<string, never>; res: true }
  qrStart: { req: Record<string, never>; res: QrInfo }
  qrPoll: { req: Record<string, never>; res: QrPollReply }
  signOut: { req: Record<string, never>; res: true }
}
export type Kind = keyof Requests
export type Message<K extends Kind = Kind> = { [P in K]: { kind: P } & Requests[P]['req'] }[K]
export type Reply<K extends Kind> = { ok: true; data: Requests[K]['res'] } | { ok: false; error: string }

export class RequestError extends Error {}

export async function send<K extends Kind>(kind: K, req: Requests[K]['req']): Promise<Requests[K]['res']> {
  const r = (await chrome.runtime.sendMessage({ kind, ...req })) as Reply<K> | undefined
  if (!r) throw new RequestError('no_reply')
  if (!r.ok) throw new RequestError(r.error)
  return r.data
}
