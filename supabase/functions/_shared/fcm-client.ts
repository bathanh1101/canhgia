// FCM HTTP v1 sender. OAuth access token is minted from the service account (RS256 JWT) and cached until near expiry.
export type FcmResult = 'ok' | 'unregistered' | 'error'
export interface FcmMessage {
  title: string
  body: string
  data: Record<string, string>
}
export interface FcmClient {
  send(token: string, m: FcmMessage): Promise<FcmResult>
}

interface ServiceAccount {
  client_email: string
  private_key: string
  token_uri?: string
}
const b64u = (b: ArrayBuffer | string) =>
  btoa(typeof b === 'string' ? b : String.fromCharCode(...new Uint8Array(b))).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')

export function createFcmClient(
  o: { projectId: string; serviceAccountJson: string; fetchFn?: typeof fetch; now?: () => number },
): FcmClient {
  const fetchFn = o.fetchFn ?? fetch
  const now = o.now ?? Date.now
  const sa = JSON.parse(o.serviceAccountJson) as ServiceAccount
  if (!sa.client_email || !sa.private_key) throw new Error('FCM_SERVICE_ACCOUNT_JSON: client_email/private_key missing')
  const tokenUri = sa.token_uri ?? 'https://oauth2.googleapis.com/token'
  let cached: { token: string; exp: number } | null = null

  async function accessToken(): Promise<string> {
    if (cached && cached.exp - 60_000 > now()) return cached.token
    const iat = Math.floor(now() / 1000)
    const unsigned = `${b64u(JSON.stringify({ alg: 'RS256', typ: 'JWT' }))}.${
      b64u(JSON.stringify({
        iss: sa.client_email,
        scope: 'https://www.googleapis.com/auth/firebase.messaging',
        aud: tokenUri,
        iat,
        exp: iat + 3600,
      }))
    }`
    const der = Uint8Array.from(atob(sa.private_key.replace(/-----[A-Z ]+-----|\s/g, '')), (c) => c.charCodeAt(0))
    const key = await crypto.subtle.importKey('pkcs8', der, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign'])
    const sig = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(unsigned))
    const res = await fetchFn(tokenUri, {
      method: 'POST',
      headers: { 'content-type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion: `${unsigned}.${b64u(sig)}` }),
    })
    const j = await res.json().catch(() => null) as { access_token?: string; expires_in?: number } | null
    if (!res.ok || !j?.access_token) throw new Error(`fcm oauth ${res.status}`)
    cached = { token: j.access_token, exp: now() + (j.expires_in ?? 3600) * 1000 }
    return cached.token
  }

  return {
    async send(token, m) {
      const res = await fetchFn(`https://fcm.googleapis.com/v1/projects/${o.projectId}/messages:send`, {
        method: 'POST',
        headers: { authorization: `Bearer ${await accessToken()}`, 'content-type': 'application/json' },
        body: JSON.stringify({ message: { token, notification: { title: m.title, body: m.body }, data: m.data } }),
        signal: AbortSignal.timeout(10_000),
      })
      if (res.ok) {
        await res.body?.cancel()
        return 'ok'
      }
      const j = await res.json().catch(() => null) as { error?: { details?: { errorCode?: string }[] } } | null
      // a bare 404 NOT_FOUND can be a wrong FCM_PROJECT_ID and must not wipe every token: only the UNREGISTERED detail counts
      if (j?.error?.details?.some((x) => x.errorCode === 'UNREGISTERED')) return 'unregistered'
      if (res.status === 401) cached = null
      console.error('fcm send failed', res.status)
      return 'error'
    },
  }
}
