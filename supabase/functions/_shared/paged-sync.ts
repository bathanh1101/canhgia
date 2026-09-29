// Resumable "for each work item, page until short page" loop shared by datafeeds and voucher sync.
// Cursor {idx,page} advances only after the sink committed the page. Lock is always released in finally.
import { AtError } from './accesstrade-client.ts'
import type { SyncCursor } from './sync-cursor.ts'

export const BUDGET_MS = 110_000
const LOCK_TTL_S = 150

export interface PagedResult<W> {
  skipped?: 'locked'
  done: boolean
  pages: number
  count: number
  last: W | null
  error?: string
}

export async function runPaged<W>(o: {
  cursor: SyncCursor
  job: string
  work: W[]
  pageSize: number
  now: () => number
  fetchPage: (w: W, page: number, waitMs: number) => Promise<Record<string, unknown>[]>
  sink: (w: W, rows: Record<string, unknown>[]) => Promise<number>
}): Promise<PagedResult<W>> {
  if (!(await o.cursor.lock(o.job, LOCK_TTL_S))) return { skipped: 'locked', done: false, pages: 0, count: 0, last: null }
  const r: PagedResult<W> = { done: false, pages: 0, count: 0, last: null }
  let err: string | null = null
  try {
    const st = (await o.cursor.load(o.job)).cursor as { idx?: unknown; page?: unknown } | null
    let c = Number.isInteger(st?.idx) && Number.isInteger(st?.page)
      ? { idx: st!.idx as number, page: st!.page as number }
      : { idx: 0, page: 1 }
    const deadline = o.now() + BUDGET_MS
    while (c.idx < o.work.length && o.now() < deadline) {
      const w = o.work[c.idx]
      r.last = w
      const rows = await o.fetchPage(w, c.page, deadline - o.now())
      r.pages++
      r.count += rows.length ? await o.sink(w, rows) : 0
      c = rows.length < o.pageSize ? { idx: c.idx + 1, page: 1 } : { idx: c.idx, page: c.page + 1 }
      await o.cursor.save(o.job, c)
    }
    r.done = c.idx >= o.work.length
  } catch (e) {
    err = e instanceof AtError ? e.kind : 'db'
    r.error = err
    console.error(`sync ${o.job} failed`, (e as Error).message)
  } finally {
    await o.cursor.finish(o.job, { success: r.done && !err, error: err, windowUntil: new Date(o.now()).toISOString() })
  }
  return r
}
