import { HttpError, json, readBody, requireCronSecret, wrap } from '../_shared/request-guards.ts'
import { type Db, rpc } from '../_shared/supabase-admin-client.ts'
import { type AtClient, AtError, dataArray, JOB_RETRIES } from '../_shared/accesstrade-client.ts'
import type { SyncCursor } from '../_shared/sync-cursor.ts'
import { type MerchantRow, SHORT_HOSTS } from '../_shared/merchant-url-parser.ts'
import { runPaged } from '../_shared/paged-sync.ts'
import { mapVoucher } from './voucher-mapper.ts'

const VOUCHER_PAGE = 100 // offers_informations max
const CAMPAIGN_PAGE = 50 // campaigns max

export interface Deps {
  db: Db
  at: AtClient
  cursor: SyncCursor
  merchants: () => Promise<MerchantRow[]>
  now?: () => number
  cronSecret?: string
}

export function makeHandler(d: Deps) {
  const now = d.now ?? Date.now
  return wrap(async (req) => {
    await requireCronSecret(req, d.cronSecret)
    const what = (await readBody(req)).what
    if (what === 'vouchers') return json(await vouchers(d, now))
    if (what === 'campaigns') return json(await campaigns(d, now))
    throw new HttpError(400, 'invalid_input', 'what')
  })
}

async function vouchers(d: Deps, now: () => number) {
  const work = (await d.merchants()).flatMap((m) =>
    m.domains.filter((x) => !SHORT_HOSTS.includes(x)).map((domain) => ({ id: m.id, domain }))
  )
  const r = await runPaged({
    cursor: d.cursor,
    job: 'catalog_vouchers',
    work,
    pageSize: VOUCHER_PAGE,
    now,
    fetchPage: async (w, page, waitMs) =>
      dataArray(
        await d.at.get('/v1/offers_informations', {
          bucket: 'catalog',
          retries: JOB_RETRIES,
          waitMs,
          params: { domain: w.domain, limit: VOUCHER_PAGE, page }, // coupon=1 returns 0 rows (live 2026-09-29)
        }),
        'offers_informations',
      ),
    sink: async (w, raw) => {
      const rows = raw.map((x) => mapVoucher(w.id, x)).filter((x) => x !== null)
      return rows.length ? await rpc<number>(d.db, 'upsert_vouchers', { p_rows: rows }) : 0
    },
  })
  return r.skipped ? { skipped: r.skipped } : { pages: r.pages, vouchers: r.count, done: r.done, ...(r.error ? { error: r.error } : {}) }
}

// Commission bps are per-merchant config: GET /v1/commission_policies is 404 on this account (01 spike), so it is
// not called. Campaigns are only checked against merchants.at_campaign_id so a lapsed approval shows up in the logs.
async function campaigns(d: Deps, now: () => number) {
  const job = 'catalog_campaigns'
  if (!(await d.cursor.lock(job, 150))) return { skipped: 'locked' }
  let error: string | null = null
  const approved = new Set<string>()
  let total = 0
  let unapproved: string[] = []
  try {
    for (let page = 1, last = 1; page <= last; page++) {
      const res = await d.at.get('/v1/campaigns', {
        bucket: 'catalog',
        retries: JOB_RETRIES,
        waitMs: 60_000,
        params: { limit: CAMPAIGN_PAGE, page },
      })
      const rows = dataArray(res, 'campaigns')
      last = Math.min(Number((res as { total_page?: unknown }).total_page) || 1, 20)
      total += rows.length
      for (const c of rows) if (c.approval === 'successful') approved.add(String(c.id))
    }
    unapproved = (await d.merchants()).filter((m) => m.at_campaign_id && !approved.has(m.at_campaign_id)).map((m) => m.id)
    if (unapproved.length) console.warn('campaign not approved for merchants:', unapproved.join(','))
  } catch (e) {
    error = e instanceof AtError ? e.kind : 'db'
    console.error('sync catalog_campaigns failed', (e as Error).message)
  } finally {
    await d.cursor.finish(job, { success: !error, error, windowUntil: new Date(now()).toISOString() })
  }
  return {
    campaigns: total,
    unapproved_merchants: unapproved,
    commissions: 0,
    warning: 'commission_policies_unavailable',
    ...(error ? { error } : {}),
  }
}
