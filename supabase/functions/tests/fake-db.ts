// In-memory stand-in for the Supabase client: rpc handlers + tiny table query builder + auth.admin. Test-only.
import type { Db } from '../_shared/supabase-admin-client.ts'

type Row = Record<string, unknown>
type Handler = (args: Record<string, unknown>) => unknown
export interface FakeDb extends Db {
  calls: { fn: string; args: Record<string, unknown> }[]
  tables: Record<string, Row[]>
  handlers: Record<string, Handler>
}

export function makeFakeDb(
  o: { handlers?: Record<string, Handler>; tables?: Record<string, Row[]>; auth?: unknown; clock?: () => number } = {},
): FakeDb {
  const calls: FakeDb['calls'] = []
  const tables = o.tables ?? {}
  const handlers = o.handlers ?? {}
  const db = {
    calls,
    tables,
    handlers,
    auth: o.auth,
    // deno-lint-ignore require-await
    async rpc(fn: string, args: Record<string, unknown> = {}) {
      calls.push({ fn, args })
      try {
        const h = handlers[fn]
        if (!h) return { data: null, error: { message: `no fake handler ${fn}` } }
        return { data: h(args), error: null }
      } catch (e) {
        return { data: null, error: { message: (e as Error).message } }
      }
    },
    from(t: string) {
      let rows = [...(tables[t] ?? [])]
      let del = false
      const q = {
        select: () => q,
        eq: (c: string, v: unknown) => {
          rows = rows.filter((r) => r[c] === v)
          return q
        },
        in: (c: string, vs: unknown[]) => {
          rows = rows.filter((r) => vs.map(String).includes(String(r[c])))
          if (del) tables[t] = (tables[t] ?? []).filter((r) => !rows.includes(r))
          return q
        },
        delete: () => {
          del = true
          return q
        },
        maybeSingle: () => Promise.resolve({ data: rows[0] ?? null, error: null }),
        then: (res: (v: unknown) => unknown) => Promise.resolve({ data: rows, error: null }).then(res),
      }
      return q
    },
  }
  return db as unknown as FakeDb
}

/** Token bucket behaving like SQL at_rate_limit_take (cap 10, refill 10/min) on an injected clock. */
export function fakeBucket(clock: () => number, cap = 10, perMin = 10) {
  const b = new Map<string, { t: number; at: number }>()
  return (args: Record<string, unknown>) => {
    const k = String(args.p_bucket)
    const s = b.get(k) ?? { t: cap, at: clock() }
    const t = Math.min(cap, s.t + (perMin * (clock() - s.at)) / 60_000)
    const ok = t >= Number(args.p_cost)
    b.set(k, { t: ok ? t - Number(args.p_cost) : t, at: clock() })
    return ok
  }
}

/** sync_lock/save/finish + sync_state table with the same semantics as the 02a SQL. */
export function syncHandlers(db: () => FakeDb, clock: () => number): Record<string, Handler> {
  const st = (job: string) => {
    const t = db().tables.sync_state ?? (db().tables.sync_state = [])
    return t.find((r) => r.job === job) ??
      (t.push({ job, cursor: null, last_success_at: null, last_error: null, locked_until: null }), t[t.length - 1])
  }
  return {
    sync_lock: (a) => {
      const r = st(String(a.p_job))
      if (r.locked_until && Number(r.locked_until) > clock()) return false
      r.locked_until = clock() + Number(a.p_ttl_s) * 1000
      return true
    },
    sync_save: (a) => {
      st(String(a.p_job)).cursor = a.p_cursor
      return null
    },
    sync_finish: (a) => {
      const r = st(String(a.p_job))
      r.locked_until = null
      r.last_error = a.p_success ? null : a.p_error
      if (a.p_success) {
        r.last_success_at = a.p_window_until
        r.cursor = null
      }
      return null
    },
  }
}
