export const DEFAULT_PAGE_SIZE = 20;
export const MAX_PAGE_SIZE = 100;

type Param = string | string[] | undefined;

function toInt(v: Param, fallback: number): number {
  const s = Array.isArray(v) ? v[0] : v;
  const n = Number(s);
  return Number.isInteger(n) && n > 0 ? n : fallback;
}

/** Parses `?page=&size=` from searchParams; invalid values fall back, size is clamped. */
export function parsePagination(sp: Record<string, Param>, defaultSize = DEFAULT_PAGE_SIZE) {
  const size = Math.min(toInt(sp.size, defaultSize), MAX_PAGE_SIZE);
  const page = toInt(sp.page, 1);
  return { page, size, from: (page - 1) * size, to: page * size - 1 }; // from/to = Supabase .range()
}

export function pageCount(total: number, size: number): number {
  if (!Number.isFinite(total) || total <= 0 || size <= 0) return 1;
  return Math.max(1, Math.ceil(total / size));
}

/** Visible page numbers with `null` as ellipsis: 1 … 4 5 6 … 20 */
export function pageWindow(page: number, pages: number, radius = 1): (number | null)[] {
  const keep = new Set([1, pages]);
  for (let i = page - radius; i <= page + radius; i++) if (i >= 1 && i <= pages) keep.add(i);
  const sorted = [...keep].sort((a, b) => a - b);
  const out: (number | null)[] = [];
  sorted.forEach((n, i) => {
    if (i > 0 && n - sorted[i - 1] > 1) out.push(null);
    out.push(n);
  });
  return out;
}

/** Builds a query string keeping current filters, replacing page. */
export function withPage(sp: Record<string, Param>, page: number): string {
  const q = new URLSearchParams();
  for (const [k, v] of Object.entries(sp)) {
    const val = Array.isArray(v) ? v[0] : v;
    if (val !== undefined && val !== "" && k !== "page") q.set(k, val);
  }
  if (page > 1) q.set("page", String(page));
  const s = q.toString();
  return s ? `?${s}` : "?";
}
