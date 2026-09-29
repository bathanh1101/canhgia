// AccessTrade HTTP client. Every call takes a token from the shared Postgres bucket first (isolates share nothing).
import { type Db, rpc } from './supabase-admin-client.ts'

export type Bucket = 'transactions' | 'product_link' | 'datafeeds' | 'catalog'
export type AtErrorKind = 'rate_limited' | 'auth' | 'upstream' | 'db'

export class AtError extends Error {
  constructor(public kind: AtErrorKind, msg: string) {
    super(`${kind}: ${msg}`)
  }
}

export interface AtRequest {
  bucket: Bucket
  params?: Record<string, string | number>
  body?: unknown
  /** back-off delays before retrying 5xx/timeouts; jobs [1000,4000,16000], user calls [500] */
  retries?: number[]
  /** how long to wait for an empty bucket before failing rate_limited; 0 = fail at once */
  waitMs?: number
  timeoutMs?: number
}

export interface AtClient {
  get(path: string, o: AtRequest): Promise<unknown>
  post(path: string, o: AtRequest): Promise<unknown>
}

export interface AtDeps {
  db: Db
  baseUrl: string
  token: string
  fetchFn?: typeof fetch
  sleep?: (ms: number) => Promise<void>
  now?: () => number
}

const REFILL_POLL_MS = 6000 // 10 req/min per bucket

export function createAtClient(d: AtDeps): AtClient {
  const fetchFn = d.fetchFn ?? fetch
  const sleep = d.sleep ?? ((ms) => new Promise<void>((r) => setTimeout(r, ms)))
  const now = d.now ?? Date.now

  async function take(bucket: Bucket, waitMs: number): Promise<void> {
    const until = now() + waitMs
    for (;;) {
      let ok: boolean
      try {
        ok = await rpc<boolean>(d.db, 'at_rate_limit_take', { p_cost: 1, p_bucket: bucket })
      } catch (e) {
        throw new AtError('db', (e as Error).message)
      }
      if (ok) return
      if (now() + REFILL_POLL_MS > until) throw new AtError('rate_limited', `bucket ${bucket} empty`)
      await sleep(REFILL_POLL_MS)
    }
  }

  async function call(method: 'GET' | 'POST', path: string, o: AtRequest): Promise<unknown> {
    const url = new URL(path, d.baseUrl)
    for (const [k, v] of Object.entries(o.params ?? {})) url.searchParams.set(k, String(v))
    const delays = o.retries ?? [500]
    for (let attempt = 0;; attempt++) {
      await take(o.bucket, o.waitMs ?? 0)
      let res: Response | null = null
      let failure = ''
      try {
        res = await fetchFn(url, {
          method,
          headers: { Authorization: `token ${d.token}`, 'Content-Type': 'application/json' },
          body: method === 'POST' ? JSON.stringify(o.body ?? {}) : undefined,
          signal: AbortSignal.timeout(o.timeoutMs ?? 15000),
        })
      } catch (e) {
        failure = `network ${(e as Error).name}`
      }
      if (res) {
        if (res.status === 429) {
          await res.body?.cancel()
          throw new AtError('rate_limited', `429 ${path}`)
        }
        if (res.status === 401 || res.status === 403) {
          await res.body?.cancel()
          throw new AtError('auth', `${res.status} ${path}`)
        }
        if (res.ok) {
          try {
            return await res.json()
          } catch {
            throw new AtError('upstream', `invalid json ${path}`)
          }
        }
        await res.body?.cancel()
        if (res.status < 500) throw new AtError('upstream', `${res.status} ${path}`)
        failure = `${res.status}`
      }
      if (attempt >= delays.length) throw new AtError('upstream', `${failure} ${path}`)
      await sleep(delays[attempt])
    }
  }

  return { get: (p, o) => call('GET', p, o), post: (p, o) => call('POST', p, o) }
}

export function atFromEnv(db: Db): AtClient {
  const token = Deno.env.get('ACCESSTRADE_TOKEN')
  if (!token) throw new Error('missing env ACCESSTRADE_TOKEN')
  return createAtClient({ db, token, baseUrl: Deno.env.get('ACCESSTRADE_BASE_URL') ?? 'https://api.accesstrade.vn' })
}

export const JOB_RETRIES = [1000, 4000, 16000]

/** Reads `data` as an array from an AT list response, else upstream error (never trust the shape). */
export function dataArray(res: unknown, what: string): Record<string, unknown>[] {
  const d = (res as { data?: unknown } | null)?.data
  if (!Array.isArray(d)) throw new AtError('upstream', `${what}: data is not an array`)
  return d as Record<string, unknown>[]
}
