import { RATES_TTL_MS } from './config'
import type { MerchantRate } from './types'
import { parseRates } from './validators'

const KEY = 'rates'

export async function cachedRates(fetchRates: () => Promise<unknown>, now = Date.now()): Promise<MerchantRate[]> {
  const c = (await chrome.storage.local.get(KEY))[KEY] as { at: number; data: MerchantRate[] } | undefined
  if (c && now - c.at < RATES_TTL_MS && Array.isArray(c.data)) return c.data
  try {
    const data = parseRates(await fetchRates())
    await chrome.storage.local.set({ [KEY]: { at: now, data } })
    return data
  } catch (e) {
    if (c && Array.isArray(c.data)) return c.data // stale beats nothing when the network is down
    throw e
  }
}
