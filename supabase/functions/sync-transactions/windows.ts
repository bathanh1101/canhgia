// Pure window arithmetic for tx sync. All timestamps ISO-8601 UTC strings (no ms) as AccessTrade expects.
export type TxWindow = 'recent' | 'older'
export interface TxCursor {
  since: string
  until: string
  page: number
  end?: string
}

const MIN = 60_000
const DAY = 24 * 60 * MIN
const iso = (ms: number) => new Date(ms).toISOString().replace(/\.\d{3}Z$/, 'Z')
const ms = (s: string) => Date.parse(s)

export function openWindow(w: TxWindow, lastSuccess: string | null, now: number): TxCursor {
  if (w === 'recent') {
    const since = lastSuccess ? ms(lastSuccess) - 30 * MIN : now - 3 * DAY
    return { since: iso(since), until: iso(now), page: 1 }
  }
  const start = now - 180 * DAY
  const end = now - 3 * DAY
  return { since: iso(start), until: iso(Math.min(start + 7 * DAY, end)), page: 1, end: iso(end) }
}

/** Next slice of an older sweep, or null when the sweep (or a recent window) is complete. */
export function nextSlice(w: TxWindow, c: TxCursor): TxCursor | null {
  if (w === 'recent' || !c.end || ms(c.until) >= ms(c.end)) return null
  return { since: c.until, until: iso(Math.min(ms(c.until) + 7 * DAY, ms(c.end))), page: 1, end: c.end }
}

export const windowUntil = (w: TxWindow, c: TxCursor) => (w === 'older' && c.end ? c.end : c.until)

export function isCursor(v: unknown): v is TxCursor {
  const c = v as TxCursor | null
  return !!c && typeof c.since === 'string' && typeof c.until === 'string' && Number.isInteger(c.page) && c.page >= 1
}
