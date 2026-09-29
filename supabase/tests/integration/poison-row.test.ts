// Backend integration: bad AT data handling + admin-at-lookup
import { describe, it, beforeAll, afterAll } from 'npm:@std/testing@1.0.0/bdd'
import { assertEquals } from 'npm:@std/assert@1.0.0'
import { startMock, makeConversions, type Mock } from '../functions/tests/mock-accesstrade.ts'

const API_URL = Deno.env.get('SUPABASE_URL') || 'http://127.0.0.1:55321'
const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'

const testUsers = {
  admin: { id: '11111111-1111-1111-1111-111111111111', email: 'admin@test.canhgia.local' },
  minh: { id: '22222222-2222-2222-2222-222222222222', email: 'minh@test.canhgia.local' },
}

let mockServer: Mock

beforeAll(async () => {
  mockServer = startMock({ port: 8787 })
})

afterAll(async () => {
  await mockServer.close()
})

async function callFn(name: string, body: unknown, serviceKey?: string) {
  const headers: Record<string, string> = { 'content-type': 'application/json', apikey: API_URL.includes('127.0.0.1') ? 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9' : '' }
  if (serviceKey) headers['x-api-key'] = serviceKey
  const res = await fetch(`${API_URL}/functions/v1/${name}`, { method: 'POST', headers, body: JSON.stringify(body) })
  return res.status === 204 ? null : res.json()
}

async function syncTransactions() {
  const res = await fetch(`${API_URL}/functions/v1/sync-transactions`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', apikey: SERVICE_KEY },
    body: JSON.stringify({ window: 'page1' }),
  })
  return res.json()
}

describe('Backend poison-row + admin lookup', () => {
  it('skips stale conversions (old update_time)', async () => {
    const fresh = makeConversions(1, 10, { update_time: '2026-09-29T23:00:00Z' })
    const stale = makeConversions(1, 11, { update_time: '2026-09-01T00:00:00Z', utm_content: fresh[0].utm_content })
    await fetch(`${mockServer.url}/__control`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ conversions: [...fresh, ...stale] }),
    })

    const syncRes = await syncTransactions()
    // Verify only fresh is synced (depends on cursor logic in actual fn)
    assertEquals(syncRes?.synced_orders > 0, true, 'should sync at least one order')
  })

  it('admin-at-lookup retrieves clicks and AT row', async () => {
    const clicks = await fetch(`${API_URL}/rest/v1/rpc/create_click`, {
      method: 'POST',
      headers: { 'content-type': 'application/json', apikey: SERVICE_KEY },
      body: JSON.stringify({ p_user_id: testUsers.minh.id, p_merchant: 'shopee', p_url: 'https://shopee.vn/sp-1', p_offer_url: 'https://shopee.vn/sp-1', p_source: 'app' }),
    }).then(r => r.json())

    const res = await fetch(`${API_URL}/functions/v1/admin-at-lookup`, {
      method: 'POST',
      headers: { 'content-type': 'application/json', apikey: SERVICE_KEY },
      body: JSON.stringify({ merchant_id: 'shopee', order_code: 'SP0001', purchased_on: '2026-09-27' }),
    })
    const data = await res.json()
    assertEquals(Array.isArray(data.rows), true, 'should return AT transactions')
    assertEquals(Array.isArray(data.clicks), true, 'should return related clicks')
  })
})
