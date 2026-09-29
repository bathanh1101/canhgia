type SP = Record<string, string | string[] | undefined>;
const DAY = 86_400_000;
const ISO = /^\d{4}-\d{2}-\d{2}$/;
const ms = (d: string) => Date.parse(`${d}T00:00:00Z`);
const fmt = (t: number) => new Date(t).toISOString().slice(0, 10);

export interface DateRange { from: string; to: string }

/** Today in Asia/Ho_Chi_Minh as YYYY-MM-DD. */
export function vnToday(now = Date.now()): string {
  return fmt(now + 7 * 3_600_000);
}

const first = (v: string | string[] | undefined) => (Array.isArray(v) ? v[0] : v);
const valid = (d: string | undefined): d is string => !!d && ISO.test(d) && !Number.isNaN(ms(d));

/** `?from&to` (inclusive days); invalid / inverted / >366-day input falls back to month-to-date. */
export function resolveRange(sp: SP, today = vnToday()): DateRange {
  const from = first(sp.from), to = first(sp.to);
  if (valid(from) && valid(to) && from <= to && ms(to) - ms(from) <= 365 * DAY) return { from, to };
  return { from: `${today.slice(0, 8)}01`, to: today };
}

/** Same-length window immediately before `r`. */
export function previousRange(r: DateRange): DateRange {
  const len = (ms(r.to) - ms(r.from)) / DAY + 1;
  const to = ms(r.from) - DAY;
  return { from: fmt(to - (len - 1) * DAY), to: fmt(to) };
}

/** Percent change vs previous (1 decimal); null when there is no baseline. */
export function deltaPct(cur: number, prev: number): number | null {
  if (!prev) return null;
  return Math.round(((cur - prev) / Math.abs(prev)) * 1000) / 10;
}

/** SVG polyline points for a tiny sparkline. */
export function sparklinePoints(values: number[], w = 120, h = 32): string {
  if (values.length === 0) return "";
  const max = Math.max(...values, 1);
  const step = values.length > 1 ? w / (values.length - 1) : 0;
  return values.map((v, i) => `${(i * step).toFixed(1)},${(h - (v / max) * h).toFixed(1)}`).join(" ");
}

export interface UserStatsData { newUsersMonth: number; d30Retention: number; dau: { day: string; count: number }[] }

/** admin_user_stats returns jsonb: validate shape at the boundary. */
export function parseUserStats(j: unknown): UserStatsData | null {
  if (typeof j !== "object" || j === null) return null;
  const o = j as Record<string, unknown>;
  const num = (v: unknown) => (typeof v === "number" && Number.isFinite(v) ? v : Number(v));
  if (!Array.isArray(o.dau)) return null;
  const n = num(o.new_users_month), r = num(o.d30_retention);
  if (!Number.isFinite(n) || !Number.isFinite(r)) return null;
  const dau = o.dau.flatMap((d) => {
    const x = d as { day?: unknown; count?: unknown };
    return typeof x?.day === "string" && Number.isFinite(Number(x.count)) ? [{ day: x.day, count: Number(x.count) }] : [];
  });
  return { newUsersMonth: n, d30Retention: r, dau };
}

export interface SyncStateRow { job: string; last_success_at: string | null; last_error: string | null }
export interface SyncJobView { job: string; level: "ok" | "warn" | "bad"; text: string }

const TX_STALE_MS = 2 * 3_600_000;

/** Red when tx_recent is stale (>2h) or never succeeded, or any job carries last_error. */
export function evaluateSync(rows: SyncStateRow[], now = Date.now()): SyncJobView[] {
  return rows.map((r) => {
    const age = r.last_success_at ? now - Date.parse(r.last_success_at) : Infinity;
    if (r.last_error) return { job: r.job, level: "bad", text: r.last_error };
    if (r.job === "tx_recent" && age > TX_STALE_MS) return { job: r.job, level: "bad", text: "Quá 2 giờ chưa đồng bộ" };
    if (!r.last_success_at) return { job: r.job, level: "warn", text: "Chưa chạy" };
    return { job: r.job, level: "ok", text: "Ổn định" };
  });
}

export const UNMATCHED_ALERT_RATIO = 0.15;
