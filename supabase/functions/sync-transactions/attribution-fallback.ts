// AMBIGUOUS (01 spike): utm_content round-trip is unverified. If a row arrives without a valid utm_content but with a
// numeric sub1 (= clickId, sent by create-link), rebuild utm_content from the clicks table so SQL matching still works.
// Rows with neither stay unmatched (ingest inserts them with user_id null = the unmatched queue).
import type { Db } from '../_shared/supabase-admin-client.ts'

export type Row = Record<string, unknown>
const UTM = /^u\d+c\d+$/

const sub1Of = (r: Row): string | null => {
  const v = r.sub1 ?? (r._extra as Row | undefined)?.sub1
  return typeof v === 'string' && /^\d{1,18}$/.test(v) ? v : typeof v === 'number' && Number.isSafeInteger(v) ? String(v) : null
}

export async function withSub1Fallback(db: Db, rows: Row[]): Promise<Row[]> {
  const need = rows.filter((r) => !UTM.test(String(r.utm_content ?? '')) && sub1Of(r))
  if (need.length === 0) return rows
  const { data, error } = await db.from('clicks').select('id,utm_content').in('id', need.map((r) => sub1Of(r)!))
  if (error) throw new Error(`sub1 fallback: ${error.message}`)
  const byId = new Map((data ?? []).map((c: { id: number; utm_content: string | null }) => [String(c.id), c.utm_content]))
  return rows.map((r) => {
    const utm = need.includes(r) ? byId.get(sub1Of(r)!) : null
    return utm ? { ...r, utm_content: utm } : r
  })
}
