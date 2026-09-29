// Wraps the 02a sync_state functions. Cursor advances only after the page it points past is committed.
import { type Db, rpc } from './supabase-admin-client.ts'

export interface SyncState {
  cursor: unknown | null
  last_success_at: string | null
}
export interface FinishArgs {
  success: boolean
  error: string | null
  windowUntil?: string | null
}

export interface SyncCursor {
  lock(job: string, ttlS: number): Promise<boolean>
  load(job: string): Promise<SyncState>
  save(job: string, cursor: unknown): Promise<void>
  finish(job: string, a: FinishArgs): Promise<void>
}

export function createSyncCursor(db: Db): SyncCursor {
  return {
    lock: (job, ttlS) => rpc<boolean>(db, 'sync_lock', { p_job: job, p_ttl_s: ttlS }),
    async load(job) {
      const { data, error } = await db.from('sync_state').select('cursor,last_success_at').eq('job', job).maybeSingle()
      if (error) throw new Error(`sync_state load: ${error.message}`)
      return { cursor: data?.cursor ?? null, last_success_at: data?.last_success_at ?? null }
    },
    async save(job, cursor) {
      await rpc(db, 'sync_save', { p_job: job, p_cursor: cursor })
    },
    async finish(job, a) {
      await rpc(db, 'sync_finish', {
        p_job: job,
        p_success: a.success,
        p_error: a.error,
        p_window_until: a.success ? (a.windowUntil ?? null) : null,
      })
    },
  }
}
