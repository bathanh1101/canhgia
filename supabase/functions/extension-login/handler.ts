import { isIP } from 'node:net'
import { HttpError, json, readBody, str, wrap } from '../_shared/request-guards.ts'
import { type Db, rpc } from '../_shared/supabase-admin-client.ts'

export interface Deps {
  db: Db
}
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
const SHA256_HEX = /^[0-9a-f]{64}$/

// Platform-set x-forwarded-for, first hop (INFERRED: verify on the deployed gateway). No usable IP -> fail closed,
// otherwise the per-IP limit in SQL would never bite.
function clientIp(req: Request): string {
  const ip = req.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ?? ''
  if (!isIP(ip)) throw new HttpError(400, 'invalid_input', 'client ip')
  return ip
}

export function makeHandler(d: Deps) {
  return wrap(async (req) => {
    const b = await readBody(req)
    if (b.action === 'start') {
      const hash = str(b, 'client_secret_hash', 64)!
      if (!SHA256_HEX.test(hash)) throw new HttpError(400, 'invalid_input', 'client_secret_hash')
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
      const { data: u, error: ue } = await d.db.auth.admin.getUserById(userId)
      if (ue || !u.user?.email) throw new Error(`extension-login: user lookup failed: ${ue?.message ?? 'no email'}`)
      const { data: l, error: le } = await d.db.auth.admin.generateLink({ type: 'magiclink', email: u.user.email })
      if (le || !l.properties?.hashed_token) throw new Error(`extension-login: generateLink failed: ${le?.message ?? 'no token'}`)
      return json({ token_hash: l.properties.hashed_token })
    }
    throw new HttpError(400, 'invalid_input', 'action')
  })
}
