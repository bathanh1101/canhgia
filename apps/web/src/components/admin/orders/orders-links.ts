type SP = Record<string, string | string[] | undefined>;

/** Current searchParams with `key` set (or removed when value is null), as "?a=b" / "". */
export function withParam(sp: SP, key: string, value: string | null): string {
  const q = new URLSearchParams();
  for (const [k, v] of Object.entries(sp)) {
    const val = Array.isArray(v) ? v[0] : v;
    if (val && k !== key) q.set(k, val);
  }
  if (value !== null) q.set(key, value);
  const s = q.toString();
  return s ? `?${s}` : "?";
}
