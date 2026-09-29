import { makeHandler } from './handler.ts'
import { adminClient } from '../_shared/supabase-admin-client.ts'

Deno.serve(makeHandler({ db: adminClient() }))
