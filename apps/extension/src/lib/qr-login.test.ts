import { describe, expect, it, vi } from 'vitest'
import { makeEdgePost } from './edge-client'
import { qrPoll, qrStart, sha256Hex } from './qr-login'

const CODE = '3f2b8c1e-0d4a-4a6e-9f5b-1c2d3e4f5a6b'
type Call = { url: string; headers: Record<string, string>; body: Record<string, string> }

function server(replies: { status: number; body: unknown }[]) {
  const calls: Call[] = []
  const fetchFn = vi.fn(async (url: string, init: RequestInit) => {
    calls.push({ url, headers: init.headers as Record<string, string>, body: JSON.parse(init.body as string) })
    const r = replies.shift() ?? { status: 500, body: {} }
    return new Response(JSON.stringify(r.body), { status: r.status })
  })
  const post = makeEdgePost({ url: 'http://x', key: 'pk', getToken: async () => null, fetchFn: fetchFn as unknown as typeof fetch })
  return { calls, post }
}

describe('sha256Hex', () => {
  it('matches the known vector', async () => expect(await sha256Hex('abc')).toBe('ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'))
})

describe('qrStart', () => {
  it('sends only sha256(secret); QR payload carries the code only', async () => {
    const s = server([{ status: 200, body: { code: CODE, expires_at: '2026-09-29T10:02:00Z' } }])
    const q = await qrStart(s.post)
    expect(q.payload).toBe(`canhgia-ext:${CODE}`)
    expect(q.secret).toMatch(/^[0-9a-f]{64}$/)
    expect(s.calls[0]!.body.client_secret_hash).toBe(await sha256Hex(q.secret))
    expect(JSON.stringify(s.calls[0]!.body)).not.toContain(q.secret)
    expect(q.payload).not.toContain(q.secret)
    expect(s.calls[0]!.headers.authorization).toBeUndefined() // anon call
  })
  it('two sessions never share a secret', async () => {
    const s = server([{ status: 200, body: { code: CODE, expires_at: '2026-09-29T10:02:00Z' } }, { status: 200, body: { code: CODE, expires_at: '2026-09-29T10:02:00Z' } }])
    expect((await qrStart(s.post)).secret).not.toBe((await qrStart(s.post)).secret)
  })
  it('rejects a malformed response and HTTP errors', async () => {
    await expect(qrStart(server([{ status: 200, body: { code: CODE } }]).post)).rejects.toThrow()
    await expect(qrStart(server([{ status: 429, body: { error: 'rate_limited' } }]).post)).rejects.toThrow('429 rate_limited')
  })
})

describe('qrPoll', () => {
  const sess = { code: CODE, secret: 'ab'.repeat(32), expiresAt: 10_000 }
  it('202 -> pending, and posts code + secret', async () => {
    const s = server([{ status: 202, body: { status: 'pending' } }])
    expect(await qrPoll(s.post, sess, 0)).toEqual({ state: 'pending' })
    expect(s.calls[0]!.body).toEqual({ action: 'poll', code: CODE, client_secret: sess.secret })
  })
  it('200 -> approved with token_hash', async () => expect(await qrPoll(server([{ status: 200, body: { token_hash: 'th' } }]).post, sess, 0)).toEqual({ state: 'approved', tokenHash: 'th' }))
  it('410 (wrong secret / consumed / expired) -> expired, never a token', async () => expect(await qrPoll(server([{ status: 410, body: { error: 'code_invalid' } }]).post, sess, 0)).toEqual({ state: 'expired' }))
  it('local expiry short-circuits without a request', async () => {
    const s = server([])
    expect(await qrPoll(s.post, sess, 10_000)).toEqual({ state: 'expired' })
    expect(s.calls).toHaveLength(0)
  })
  it('200 without token_hash is an error, not an approval', async () => {
    await expect(qrPoll(server([{ status: 200, body: {} }]).post, sess, 0)).rejects.toThrow()
  })
})

describe('edge post with user auth', () => {
  it('adds bearer + apikey, fails closed without a session', async () => {
    const fetchFn = vi.fn(async () => new Response('{}', { status: 200 }))
    const post = makeEdgePost({ url: 'http://x', key: 'pk', getToken: async () => 'jwt', fetchFn: fetchFn as unknown as typeof fetch })
    await post('create-link', {}, true)
    const h = (fetchFn.mock.calls[0] as unknown as [string, RequestInit])[1].headers as Record<string, string>
    expect(h.authorization).toBe('Bearer jwt')
    expect(h.apikey).toBe('pk')
    const anon = makeEdgePost({ url: 'http://x', key: 'pk', getToken: async () => null, fetchFn: fetchFn as unknown as typeof fetch })
    await expect(anon('create-link', {}, true)).rejects.toThrow('not_logged_in')
  })
})
