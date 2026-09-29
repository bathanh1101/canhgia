import { HttpError, json, readBody, requireCronSecret, wrap } from '../_shared/request-guards.ts'
import { type Db, rpc } from '../_shared/supabase-admin-client.ts'
import { type AtClient, AtError, dataArray, JOB_RETRIES } from '../_shared/accesstrade-client.ts'
import type { SyncCursor } from '../_shared/sync-cursor.ts'
import { isCursor, nextSlice, openWindow, type TxCursor, type TxWindow, windowUntil } from './windows.ts'
import { withSub1Fallback } from './attribution-fallback.ts'

export const LIMIT = 100 // documented default; max unproven (spike: empty result set)
export const BUDGET_MS = 110_000
const LOCK_TTL_S = 150

export interface Deps {
  db: Db
  at: AtClient
  cursor: SyncCursor
  now?: () => number
  cronSecret?: string
}

interface Stats {
  pages: number
  inserted: number
  updated: number
  skipped: number
  unmatched: number
  errors: number
  done: boolean
}
const emptyStats = (): Stats => ({ pages: 0, inserted: 0, updated: 0, skipped: 0, unmatched: 0, errors: 0, done: false })

export function makeHandler(d: Deps) {
  const now = d.now ?? Date.now
  return wrap(async (req) => {
    await requireCronSecret(req, d.cronSecret)
    const w = (await readBody(req)).window
    if (w !== 'recent' && w !== 'older') throw new HttpError(400, 'invalid_input', 'window')
    return json(await run(d, w, now))
  })
}

async function run(d: Deps, w: TxWindow, now: () => number) {
  const job = `tx_${w}`
  if (!(await d.cursor.lock(job, LOCK_TTL_S))) return { skipped: 'locked' }
  const stats = emptyStats()
  let err: string | null = null
  let c: TxCursor | null = null
  try {
    const st = await d.cursor.load(job)
    c = isCursor(st.cursor) ? st.cursor : openWindow(w, st.last_success_at, now())
    const deadline = now() + BUDGET_MS
    while (now() < deadline) {
      const res = await d.at.get('/v1/transactions', {
        bucket: 'transactions',
        params: { since: c.since, until: c.until, page: c.page, limit: LIMIT },
        retries: JOB_RETRIES,
        waitMs: deadline - now(),
      })
      const rows = await withSub1Fallback(d.db, dataArray(res, 'transactions'))
      stats.pages++
      if (rows.length) {
        const out = await rpc<{ status: string }[]>(d.db, 'ingest_at_transactions', { p_job: job, p_rows: rows })
        for (const o of out) {
          const k = o.status === 'error' ? 'errors' : o.status
          if (k === 'inserted' || k === 'updated' || k === 'skipped' || k === 'unmatched' || k === 'errors') stats[k]++
        }
      }
      if (rows.length < LIMIT) {
        const n = nextSlice(w, c)
        if (!n) {
          stats.done = true
          break
        }
        c = n
      } else {
        c = { ...c, page: c.page + 1 }
      }
      await d.cursor.save(job, c) // advance only after the page is committed
    }
  } catch (e) {
    err = e instanceof AtError ? e.kind : 'db'
    console.error(`sync ${job} failed`, (e as Error).message)
  } finally {
    await d.cursor.finish(job, { success: stats.done && !err, error: err, windowUntil: c ? windowUntil(w, c) : null })
  }
  return { ...stats, ...(err ? { error: err } : {}) }
}
