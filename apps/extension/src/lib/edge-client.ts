export interface EdgeReply {
  status: number
  json: unknown
}
export type EdgePost = (fn: string, body: unknown, withUser: boolean) => Promise<EdgeReply>

export class ApiError extends Error {
  constructor(public status: number, public code: string) {
    super(`${status} ${code}`)
  }
}

/** POST /functions/v1/<fn>. Never throws on HTTP status (callers branch on 202/410); throws on network / non-JSON. */
export function makeEdgePost(o: { url: string; key: string; getToken: () => Promise<string | null>; fetchFn?: typeof fetch }): EdgePost {
  const f = o.fetchFn ?? fetch
  return async (fn, body, withUser) => {
    const headers: Record<string, string> = { 'content-type': 'application/json', apikey: o.key }
    if (withUser) {
      const t = await o.getToken()
      if (!t) throw new ApiError(401, 'not_logged_in')
      headers.authorization = `Bearer ${t}`
    }
    const res = await f(`${o.url}/functions/v1/${fn}`, { method: 'POST', headers, body: JSON.stringify(body) })
    let json: unknown = null
    try {
      json = await res.json()
    } catch {
      /* empty or non-JSON body: json stays null, status still tells the story */
    }
    return { status: res.status, json }
  }
}

export function expectOk(r: EdgeReply): unknown {
  if (r.status >= 200 && r.status < 300) return r.json
  const code = typeof (r.json as { error?: unknown } | null)?.error === 'string' ? (r.json as { error: string }).error : 'http_error'
  throw new ApiError(r.status, code)
}
