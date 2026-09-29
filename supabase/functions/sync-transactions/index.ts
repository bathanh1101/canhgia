import { makeHandler } from './handler.ts'
import { adminClient } from '../_shared/supabase-admin-client.ts'
import { atFromEnv } from '../_shared/accesstrade-client.ts'
import { createSyncCursor } from '../_shared/sync-cursor.ts'

const db = adminClient()
Deno.serve(makeHandler({ db, at: atFromEnv(db), cursor: createSyncCursor(db) }))
