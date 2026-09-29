import { makeHandler } from './handler.ts'
import { adminClient, requireUser } from '../_shared/supabase-admin-client.ts'
import { loadMerchants } from '../_shared/merchant-url-parser.ts'

const db = adminClient()
Deno.serve(makeHandler({ user: requireUser, merchants: () => loadMerchants(db) }))
