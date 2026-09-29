import { isIP } from 'node:net'
import { HttpError, json, readBody, str, wrap } from '../_shared/request-guards.ts'
import { type Db, rpc } from '../_shared/supabase-admin-client.ts'

export interface Deps {
  db: Db
}
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
const SHA256_HEX = /^[0-9a-f]{64}$/

const MAX_PENDING_CODES = 200 // global cap on live pending codes, so spoofed/rotating IPs cannot flood the table
const MINT_ATTEMPTS = 3

// Client IP order: cf-connecting-ip (set by Cloudflare, not client-settable), then the LAST x-forwarded-for hop
// (appended by the nearest proxy; the first hop is client-controlled). No usable IP -> fail closed, otherwise the
// per-IP limit in SQL would never bite.
export function clientIp(req: Request): string {
  const xff = req.headers.get('x-forwarded-for')?.split(',').map((s) => s.trim()).filter(Boolean) ?? []
  const ip = req.headers.get('cf-connecting-ip')?.trim() || xff[xff.length - 1] || ''
  if (!isIP(ip)) throw new HttpError(400, 'invalid_input', 'client ip')
  return ip
}

// consume already burnt the code, so a transient auth-admin failure is retried here instead of forcing a re-scan
async function mintTokenHash(db: Db, userId: string): Promise<string> {
  let last = 'unknown'
  for (let i = 0; i < MINT_ATTEMPTS; i++) {
    const { data: u, error: ue } = await db.auth.admin.getUserById(userId)
    const email = u?.user?.email
    if (ue || !email) {
      last = `user lookup: ${ue?.message ?? 'no email'}`
      if (!ue) break // no email is permanent
      continue
    }
    const { data: l, error: le } = await db.auth.admin.generateLink({ type: 'magiclink', email })
    if (!le && l.properties?.hashed_token) return l.properties.hashed_token
    last = `generateLink: ${le?.message ?? 'no token'}`
  }
  throw new Error(`extension-login: ${last}`)
}

export function makeHandler(d: Deps) {
  return wrap(async (req) => {
    const b = await readBody(req)
    if (b.action === 'start') {
      const hash = str(b, 'client_secret_hash', 64)!
      if (!SHA256_HEX.test(hash)) throw new HttpError(400, 'invalid_input', 'client_secret_hash')
      const { count, error: ce } = await d.db.from('extension_login_codes').select('code', { count: 'exact', head: true })
        .eq('status', 'pending').gt('expires_at', new Date().toISOString())
      if (ce) throw new Error(`extension-login: pending count failed: ${ce.message}`)
      if ((count ?? 0) >= MAX_PENDING_CODES) throw new HttpError(429, 'rate_limited')
      const rows = await rpc<{ code: string; expires_at: string }[]>(d.db, 'start_extension_login', {
        p_secret_hash: hash,
        p_ip: clientIp(req),
        p_user_agent: req.headers.get('user-agent') ?? '',
      }, true)
      return json({ code: rows[0].code, expires_at: rows[0].expires_at })
    }
    if (b.action === 'poll') {
      const code = str(b, 'code', 36)!
      const secret = str(b, 'client_secret', 256)!
      if (!UUID.test(code)) throw new HttpError(400, 'invalid_input', 'code')
      let userId: string
      try {
        userId = await rpc<string>(d.db, 'consume_extension_login', { p_code: code, p_secret: secret }, true)
      } catch (e) {
        if (e instanceof HttpError && e.code === 'code_pending') return json({ status: 'pending' }, 202)
        throw e // code_invalid -> 410
      }
      return json({ token_hash: await mintTokenHash(d.db, userId) })
    }
    throw new HttpError(400, 'invalid_input', 'action')
  })
}
