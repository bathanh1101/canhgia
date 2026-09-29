import { json, requireCronSecret, wrap } from '../_shared/request-guards.ts'
import { type Db, rpc } from '../_shared/supabase-admin-client.ts'
import type { FcmClient, FcmResult } from '../_shared/fcm-client.ts'

const BATCH = 100

interface Claimed {
  id: number
  user_id: string
  type: string
  title: string
  body: string
  data: Record<string, unknown> | null
  tokens: string[]
}
export interface Deps {
  db: Db
  fcm: FcmClient
  cronSecret?: string
}

// FCM data payload values must be strings
const stringify = (type: string, id: number, data: Record<string, unknown> | null) =>
  Object.fromEntries(
    Object.entries({ ...(data ?? {}), type, notification_id: id }).map(([k, v]) => [k, typeof v === 'string' ? v : JSON.stringify(v)]),
  )

export function makeHandler(d: Deps) {
  return wrap(async (req) => {
    await requireCronSecret(req, d.cronSecret)
    // claim_push_batch applies prefs and bumps push_attempts; unsent rows are re-claimed after 10 min (max 3 attempts)
    const batch = await rpc<Claimed[]>(d.db, 'claim_push_batch', { p_limit: BATCH })
    const done: number[] = []
    const dead: string[] = []
    let sent = 0
    let failed = 0
    for (const n of batch) {
      const results: FcmResult[] = []
      for (const t of n.tokens) {
        try {
          results.push(await d.fcm.send(t, { title: n.title, body: n.body, data: stringify(n.type, n.id, n.data) }))
        } catch (e) {
          console.error('fcm send threw', (e as Error).message)
          results.push('error')
        }
        if (results.at(-1) === 'unregistered') dead.push(t)
      }
      sent += results.filter((r) => r === 'ok').length
      // done when nothing left to retry: no tokens, or every token either delivered or permanently dead
      if (results.every((r) => r !== 'error')) done.push(n.id)
      else failed++
    }
    if (done.length) await rpc(d.db, 'mark_push_sent', { p_ids: done })
    if (dead.length) {
      const { error } = await d.db.from('push_tokens').delete().in('token', dead)
      if (error) console.error('drop dead tokens failed', error.message)
    }
    return json({ claimed: batch.length, sent, dropped_tokens: dead.length, failed })
  })
}
