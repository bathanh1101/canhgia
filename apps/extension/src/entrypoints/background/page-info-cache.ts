import type { PageInfo } from '../../lib/messages'

export const PAGE_INFO_TTL_MS = 30_000
const entries = new Map<string, { at: number; p: Promise<PageInfo> }>()

/** Three content scripts ask for the same page: share one in-flight/recent result per tab+url. Failures are not kept. */
export function cachedPageInfo(tabId: number, url: string, load: () => Promise<PageInfo>, now = Date.now()): Promise<PageInfo> {
  const key = `${tabId}|${url}`
  const hit = entries.get(key)
  if (hit && now - hit.at < PAGE_INFO_TTL_MS) return hit.p
  for (const [k, v] of entries) if (now - v.at >= PAGE_INFO_TTL_MS) entries.delete(k)
  const p = load()
  entries.set(key, { at: now, p })
  p.catch(() => entries.delete(key))
  return p
}

/** Login state / activation changed: cached pageInfo would be stale. */
export const clearPageInfoCache = (): void => entries.clear()
