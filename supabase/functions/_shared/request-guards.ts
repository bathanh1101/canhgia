// HTTP plumbing shared by every function: JSON replies, typed errors, cron-secret and user-JWT guards.
import type { SupabaseClient } from '@supabase/supabase-js'

export const CORS: Record<string, string> = {
  'access-control-allow-origin': '*',
  'access-control-allow-headers': 'authorization, apikey, content-type, x-client-info, x-cron-secret',
  'access-control-allow-methods': 'POST, OPTIONS',
}

export class HttpError extends Error {
  constructor(public status: number, public code: string, public detail?: unknown) {
    super(code)
  }
}

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { ...CORS, 'content-type': 'application/json' } })
}

// Wraps a handler: OPTIONS, POST-only, HttpError -> {error}, anything else -> logged 500.
export function wrap(fn: (req: Request) => Promise<Response>): (req: Request) => Promise<Response> {
  return async (req) => {
    if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers: CORS })
    try {
      if (req.method !== 'POST') throw new HttpError(405, 'invalid_input', 'POST only')
      return await fn(req)
    } catch (e) {
      if (e instanceof HttpError) return json({ error: e.code, ...(e.detail ? { detail: e.detail } : {}) }, e.status)
      console.error('unhandled', e)
      return json({ error: 'internal' }, 500)
    }
  }
}

// Error vocabulary from phase 02a -> HTTP status. Unknown messages are not domain errors.
const STATUS: Record<string, number> = {
  forbidden: 403,
  rate_limited: 429,
  account_locked: 403,
  insufficient_balance: 409,
  pin_invalid: 403,
  pin_locked: 403,
  kyc_required: 403,
  code_invalid: 410,
  code_pending: 202,
  hold_active: 409,
  daily_cap: 409,
  invalid_input: 400,
}

// PostgREST error (message = vocabulary code) -> HttpError; otherwise rethrow untouched.
export function dbError(e: { message: string } | Error): never {
  const status = STATUS[e.message]
  if (status) throw new HttpError(status, e.message)
  throw e instanceof Error ? e : new Error(e.message)
}

export async function readBody(req: Request): Promise<Record<string, unknown>> {
  let b: unknown
  try {
    b = await req.json()
  } catch {
    throw new HttpError(400, 'invalid_input', 'json body')
  }
  if (b === null || typeof b !== 'object' || Array.isArray(b)) throw new HttpError(400, 'invalid_input', 'json object')
  return b as Record<string, unknown>
}

export function str(b: Record<string, unknown>, k: string, max = 2048, optional = false): string | undefined {
  const v = b[k]
  if (v === undefined || v === null) {
    if (optional) return undefined
    throw new HttpError(400, 'invalid_input', k)
  }
  if (typeof v !== 'string' || v.length === 0 || v.length > max) throw new HttpError(400, 'invalid_input', k)
  return v
}

async function sha(s: string): Promise<Uint8Array> {
  return new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(s)))
}

// Constant-time: compare digests so length never leaks.
export async function timingSafeEqual(a: string, b: string): Promise<boolean> {
  const [x, y] = await Promise.all([sha(a), sha(b)])
  let d = 0
  for (let i = 0; i < x.length; i++) d |= x[i] ^ y[i]
  return d === 0
}

export async function requireCronSecret(req: Request, secret = Deno.env.get('CRON_SECRET')): Promise<void> {
  const got = req.headers.get('x-cron-secret')
  if (!secret || !got || !(await timingSafeEqual(got, secret))) throw new HttpError(403, 'forbidden')
}

export interface AuthedUser {
  id: string
  client: SupabaseClient
}
export type UserResolver = (req: Request) => Promise<AuthedUser>
