// Service-role + user-scoped Supabase clients and a throwing rpc helper.
import { createClient, type SupabaseClient } from '@supabase/supabase-js'
import { type AuthedUser, dbError, HttpError } from './request-guards.ts'

export type Db = SupabaseClient

function need(name: string): string {
  const v = Deno.env.get(name)
  if (!v) throw new Error(`missing env ${name}`)
  return v
}

export function adminClient(): Db {
  return createClient(need('SUPABASE_URL'), need('SUPABASE_SERVICE_ROLE_KEY'), {
    auth: { persistSession: false, autoRefreshToken: false },
  })
}

// User-scoped client (RLS + auth.uid() apply); the JWT is validated with auth.getUser.
export async function requireUser(req: Request): Promise<AuthedUser> {
  const auth = req.headers.get('authorization') ?? ''
  const jwt = auth.startsWith('Bearer ') ? auth.slice(7) : ''
  if (!jwt) throw new HttpError(401, 'forbidden')
  const client = createClient(need('SUPABASE_URL'), need('SUPABASE_ANON_KEY'), {
    global: { headers: { Authorization: `Bearer ${jwt}` } },
    auth: { persistSession: false, autoRefreshToken: false },
  })
  const { data, error } = await client.auth.getUser(jwt)
  if (error || !data.user) throw new HttpError(401, 'forbidden')
  return { id: data.user.id, client }
}

// rpc that throws on error. `domain` = true maps vocabulary codes to HttpError (user-facing paths).
export async function rpc<T = unknown>(db: Db, fn: string, args: Record<string, unknown> = {}, domain = false): Promise<T> {
  const { data, error } = await db.rpc(fn, args)
  if (error) {
    if (domain) dbError(error)
    throw new Error(`rpc ${fn}: ${error.message}`)
  }
  return data as T
}
