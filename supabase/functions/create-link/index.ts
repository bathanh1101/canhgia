import { makeHandler } from './handler.ts'
import { adminClient, requireUser } from '../_shared/supabase-admin-client.ts'
import { atFromEnv } from '../_shared/accesstrade-client.ts'
import { loadMerchants } from '../_shared/merchant-url-parser.ts'

const db = adminClient()
Deno.serve(makeHandler({ user: requireUser, db, at: atFromEnv(db), merchants: () => loadMerchants(db) }))
