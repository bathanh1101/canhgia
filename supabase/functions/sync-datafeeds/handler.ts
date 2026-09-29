import { HttpError, json, readBody, requireCronSecret, wrap } from '../_shared/request-guards.ts'
import { type Db, rpc } from '../_shared/supabase-admin-client.ts'
import { type AtClient, dataArray, jobRetries } from '../_shared/accesstrade-client.ts'
import type { SyncCursor } from '../_shared/sync-cursor.ts'
import { type MerchantRow, SHORT_HOSTS } from '../_shared/merchant-url-parser.ts'
import { runPaged } from '../_shared/paged-sync.ts'
import { mapFeedRow } from './datafeed-mapper.ts'

const PAGE = 200 // spike: limit=200 accepted
const DELTA_MIN_GAP_MS = 12 * 3600_000 // cron fires every 10 min in a 4h window; one delta per day is enough

export interface Deps {
  db: Db
  at: AtClient
  cursor: SyncCursor
  merchants: () => Promise<MerchantRow[]>
  now?: () => number
  cronSecret?: string
}

// AT expects DD-MM-YYYY; "yesterday" in ICT (UTC+7).
export function yesterdayIct(nowMs: number): string {
  const d = new Date(nowMs + 7 * 3600_000 - 24 * 3600_000)
  const p = (x: number) => String(x).padStart(2, '0')
  return `${p(d.getUTCDate())}-${p(d.getUTCMonth() + 1)}-${d.getUTCFullYear()}`
}

export function makeHandler(d: Deps) {
  const now = d.now ?? Date.now
  return wrap(async (req) => {
    await requireCronSecret(req, d.cronSecret)
    const mode = (await readBody(req)).mode
    if (mode !== 'backfill' && mode !== 'delta') throw new HttpError(400, 'invalid_input', 'mode')
    return json(await run(d, mode, now))
  })
}

async function run(d: Deps, mode: 'backfill' | 'delta', now: () => number) {
  const job = `datafeeds_${mode}`
  const prev = await d.cursor.load(job)
  const last = prev.last_success_at ? Date.parse(prev.last_success_at) : null
  // ponytail: backfill runs once; clear sync_state.datafeeds_backfill to re-run when a merchant is enabled later
  if (last !== null && (mode === 'backfill' || now() - last < DELTA_MIN_GAP_MS)) return { merchant: null, pages: 0, offers: 0, done: true }

  const work = (await d.merchants()).filter((m) => m.datafeed_enabled).sort((a, b) => a.id.localeCompare(b.id))
    .flatMap((m) => m.domains.filter((x) => !SHORT_HOSTS.includes(x)).map((domain) => ({ id: m.id, domain })))
  const r = await runPaged({
    cursor: d.cursor,
    job,
    work,
    pageSize: PAGE,
    now,
    fetchPage: async (w, page, waitMs) =>
      dataArray(
        await d.at.get('/v1/datafeeds', {
          bucket: 'datafeeds',
          retries: jobRetries(waitMs),
          waitMs,
          params: { domain: w.domain, limit: PAGE, page, ...(mode === 'delta' ? { update_from: yesterdayIct(now()) } : {}) },
        }),
        'datafeeds',
      ),
    sink: async (w, raw) => {
      const rows = raw.map(mapFeedRow).filter((x): x is Record<string, unknown> => x !== null)
      if (!rows.length) return 0
      return (await rpc<{ upserted: number }[]>(d.db, 'upsert_offers', { p_merchant_id: w.id, p_rows: rows }))[0]?.upserted ?? 0
    },
  })
  if (r.skipped) return { skipped: r.skipped }
  let post: string | undefined
  if (r.done && !r.error) { // 02b post-calls; ingest is committed, so a failure is reported, not fatal
    try {
      await rpc(d.db, 'assign_product_groups')
      await rpc(d.db, 'evaluate_price_alerts')
    } catch (e) {
      post = (e as Error).message
      console.error('post-calls failed', post)
    }
  }
  return {
    merchant: r.last?.id ?? null,
    pages: r.pages,
    offers: r.count,
    done: r.done,
    ...(r.error ? { error: r.error } : {}),
    ...(post ? { post_error: post } : {}),
  }
}
