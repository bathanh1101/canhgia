// Backend integration: extension QR-pair login flow
import { describe, it } from 'jsr:@std/testing@1.0.0/bdd'
import { assertEquals, assert } from 'jsr:@std/assert@1.0.0'

const API_URL = Deno.env.get('SUPABASE_URL') || 'http://127.0.0.1:55321'
const API_KEY = Deno.env.get('SUPABASE_ANON_KEY') || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'

const testUsers = {
  minh: { id: '22222222-2222-2222-2222-222222222222', email: 'minh@test.canhgia.local' },
}

async function callFn(name: string, body: unknown, auth?: string) {
  const headers: Record<string, string> = { 'content-type': 'application/json', apikey: API_KEY }
  if (auth) headers.authorization = auth
  const res = await fetch(`${API_URL}/functions/v1/${name}`, { method: 'POST', headers, body: JSON.stringify(body) })
  return res.status === 204 ? null : res.json()
}

describe('Backend extension-login', () => {
  it('start: generates code + expires_at', async () => {
    const res = await callFn('extension-login', { action: 'start', client_secret_hash: 'secret_hash' })
    assertEquals(typeof res.code, 'string', 'should return a code')
    assert(res.expires_at > new Date().getTime(), 'expires_at should be in future')
  })

  it('poll with wrong secret returns 410', async () => {
    const start = await callFn('extension-login', { action: 'start', client_secret_hash: 'hash1' })
    const pollRes = await fetch(`${API_URL}/functions/v1/extension-login`, {
      method: 'POST',
      headers: { 'content-type': 'application/json', apikey: API_KEY },
      body: JSON.stringify({ action: 'poll', code: start.code, client_secret: 'wrong_secret' }),
    })
    assertEquals(pollRes.status, 410, 'wrong secret should return 410')
  })

  it('approve + poll flow', async () => {
    // Start request
    const start = await callFn('extension-login', { action: 'start', client_secret_hash: 'hash2' })
    const code = start.code

    // Approve as the user (using their JWT)
    const userJwt = `Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCIsInN1YiI6IjIyMjIyMjIyLTIyMjItMjIyMi0yMjIyLTIyMjIyMjIyMjIyMjIyJ9`
    const approveRes = await callFn('extension-login', { action: 'approve', code }, userJwt)
    assertEquals(approveRes?.ok || approveRes?.token_hash, !!approveRes?.token_hash, 'approve should return token_hash')

    // Poll succeeds now (with matching secret)
    const pollRes = await fetch(`${API_URL}/functions/v1/extension-login`, {
      method: 'POST',
      headers: { 'content-type': 'application/json', apikey: API_KEY },
      body: JSON.stringify({ action: 'poll', code, client_secret: 'secret_for_hash2' }),
    })
    assertEquals(pollRes.status === 200, true, 'poll should succeed after approve')
  })
})
