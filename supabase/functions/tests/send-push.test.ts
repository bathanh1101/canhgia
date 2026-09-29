import { assertEquals } from '@std/assert'
import { makeHandler } from '../send-push/handler.ts'
import { createFcmClient, type FcmClient, type FcmResult } from '../_shared/fcm-client.ts'
import { makeFakeDb } from './fake-db.ts'

type Row = Record<string, unknown>
const N = (id: number, tokens: string[]) => ({
  id,
  user_id: 'u',
  type: 'order',
  title: `t${id}`,
  body: 'b',
  data: { order_id: 'o1', n: 5 },
  tokens,
})

function setup(batch: Row[], outcome: (token: string) => FcmResult | 'throw') {
  const sent: { token: string; data: Record<string, string> }[] = []
  const fcm: FcmClient = {
    send: (token, m) => {
      sent.push({ token, data: m.data })
      const o = outcome(token)
      return o === 'throw' ? Promise.reject(new Error('boom')) : Promise.resolve(o)
    },
  }
  const db = makeFakeDb({
    handlers: { claim_push_batch: () => batch, mark_push_sent: () => null },
    tables: { push_tokens: [{ token: 'dead' }, { token: 'ok' }] },
  })
  const h = makeHandler({ db, fcm, cronSecret: 's' })
  const call = async (secret = 's') => {
    const res = await h(new Request('http://x/', { method: 'POST', headers: { 'x-cron-secret': secret }, body: '{}' }))
    return { status: res.status, body: await res.json() as Row }
  }
  return { db, sent, call }
}

Deno.test('drains outbox: sends per token, marks sent, drops UNREGISTERED tokens', async () => {
  const s = setup([N(1, ['ok', 'dead']), N(2, [])], (t) => (t === 'dead' ? 'unregistered' : 'ok'))
  const r = await s.call()
  assertEquals(r.body, { claimed: 2, sent: 1, dropped_tokens: 1, failed: 0 })
  assertEquals(s.db.calls.find((c) => c.fn === 'mark_push_sent')!.args, { p_ids: [1, 2] })
  assertEquals(s.db.tables.push_tokens.map((t) => t.token), ['ok'])
  assertEquals(s.sent[0].data, { order_id: 'o1', n: '5', type: 'order', notification_id: '1' }) // FCM data is string-only
})

Deno.test('transient FCM failure is not marked sent (re-claimed later)', async () => {
  const s = setup([N(1, ['ok']), N(2, ['bad'])], (t) => (t === 'bad' ? 'error' : 'ok'))
  const r = await s.call()
  assertEquals([r.body.failed, s.db.calls.find((c) => c.fn === 'mark_push_sent')!.args], [1, { p_ids: [1] }])
})

Deno.test('a throwing sender does not abort the batch', async () => {
  const s = setup([N(1, ['x']), N(2, ['ok'])], (t) => (t === 'x' ? 'throw' : 'ok'))
  const r = await s.call()
  assertEquals([r.status, r.body.sent, r.body.failed], [200, 1, 1])
})

Deno.test('empty outbox: no mark_push_sent call; bad cron secret -> 403', async () => {
  const s = setup([], () => 'ok')
  assertEquals((await s.call()).body.claimed, 0)
  assertEquals(s.db.calls.some((c) => c.fn === 'mark_push_sent'), false)
  assertEquals((await s.call('wrong')).status, 403)
})

Deno.test('fcm client: mints OAuth token once, sends v1 message, maps 404 to unregistered', async () => {
  const kp = await crypto.subtle.generateKey(
    { name: 'RSASSA-PKCS1-v1_5', modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: 'SHA-256' },
    true,
    ['sign'],
  )
  const der = new Uint8Array(await crypto.subtle.exportKey('pkcs8', kp.privateKey))
  const pem = `-----BEGIN PRIVATE KEY-----\n${btoa(String.fromCharCode(...der))}\n-----END PRIVATE KEY-----`
  const urls: string[] = []
  const fetchFn: typeof fetch = (input, init) => {
    const u = String(input)
    urls.push(u)
    if (u.includes('oauth2')) return Promise.resolve(Response.json({ access_token: 'at', expires_in: 3600 }))
    const tok = JSON.parse(String(init?.body)).message.token
    return Promise.resolve(
      tok === 'gone'
        ? Response.json({ error: { details: [{ errorCode: 'UNREGISTERED' }] } }, { status: 404 })
        : tok === 'typo-project'
        ? Response.json({ error: { status: 'NOT_FOUND', message: 'Requested entity was not found.' } }, { status: 404 })
        : Response.json({ name: 'm' }),
    )
  }
  const c = createFcmClient({ projectId: 'p1', serviceAccountJson: JSON.stringify({ client_email: 'a@b', private_key: pem }), fetchFn })
  const m = { title: 't', body: 'b', data: {} }
  assertEquals([await c.send('good', m), await c.send('gone', m)], ['ok', 'unregistered'])
  // bare 404 (e.g. wrong FCM_PROJECT_ID) must not be treated as a dead token
  assertEquals(await c.send('typo-project', m), 'error')
  assertEquals(urls.filter((u) => u.includes('oauth2')).length, 1)
  assertEquals(urls[1], 'https://fcm.googleapis.com/v1/projects/p1/messages:send')
})
