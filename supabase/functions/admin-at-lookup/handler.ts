import { HttpError, json, readBody, str, type UserResolver, wrap } from '../_shared/request-guards.ts'
import { type Db, rpc } from '../_shared/supabase-admin-client.ts'
import { type AtClient, AtError, dataArray } from '../_shared/accesstrade-client.ts'
import type { MerchantRow } from '../_shared/merchant-url-parser.ts'

const DAY = 86_400_000
const MAX_PAGES = 3
const LIMIT = 100
const norm = (s: unknown) => String(s ?? '').replace(/[^A-Za-z0-9]/g, '').toUpperCase()
const iso = (ms: number) => new Date(ms).toISOString().replace(/\.\d{3}Z$/, 'Z')

export interface Deps {
  user: UserResolver
  db: Db
  at: AtClient
  merchants: () => Promise<MerchantRow[]>
}

export function makeHandler(d: Deps) {
  return wrap(async (req) => {
    const user = await d.user(req)
    // is_admin() needs the caller's aal2 JWT, so it runs on the user-scoped client, before any service-role use
    if ((await rpc<boolean>(user.client, 'is_admin')) !== true) throw new HttpError(403, 'forbidden')
    const b = await readBody(req)
    const merchantId = str(b, 'merchant_id', 64)!
    const code = norm(str(b, 'order_code', 100))
    const on = str(b, 'purchased_on', 10)!
    const t = /^\d{4}-\d{2}-\d{2}$/.test(on) ? Date.parse(`${on}T00:00:00Z`) : NaN
    if (!code || Number.isNaN(t)) throw new HttpError(400, 'invalid_input')
    const m = (await d.merchants()).find((x) => x.id === merchantId)
    if (!m) throw new HttpError(422, 'merchant_unavailable')

    const rows: Record<string, unknown>[] = []
    try {
      for (let page = 1; page <= MAX_PAGES; page++) {
        const res = dataArray(
          await d.at.get('/v1/transactions', {
            bucket: 'transactions',
            retries: [500],
            params: { since: iso(t - 3 * DAY), until: iso(t + 4 * DAY - 1000), page, limit: LIMIT },
          }),
          'transactions',
        )
        rows.push(...res.filter((r) => (r.merchant === m.at_campaign_id || r.merchant === m.id) && norm(r.transaction_id) === code))
        if (res.length < LIMIT) break
      }
    } catch (e) {
      if (e instanceof AtError && e.kind === 'rate_limited') throw new HttpError(429, 'rate_limited')
      throw e
    }
    const clickIds = rows.map((r) => /^u\d+c(\d+)$/.exec(String(r.utm_content ?? ''))?.[1]).filter((x): x is string => !!x)
    let clicks: unknown[] = []
    if (clickIds.length) {
      const { data, error } = await d.db.from('clicks').select('id,user_id,merchant_id,source,status,utm_content,created_at').in(
        'id',
        clickIds,
      )
      if (error) throw new Error(`clicks lookup: ${error.message}`)
      clicks = data
    }
    return json({ rows, clicks })
  })
}
