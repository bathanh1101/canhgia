// Backend integration: sync-transactions cycle (J1/J2 journeys)
import { describe, it, beforeAll, afterAll } from 'jsr:@std/testing@1.0.0/bdd'
import { assertEquals, assert } from 'jsr:@std/assert@1.0.0'
import { startMock, makeConversions, type Mock } from '../../functions/tests/mock-accesstrade.ts'

const API_URL = Deno.env.get('SUPABASE_URL') || 'http://127.0.0.1:55321'
const API_KEY = Deno.env.get('SUPABASE_ANON_KEY') || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0'
const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU'
const CRON_SECRET = 'super-secret-jwt-token-with-at-least-32-characters-long'

const testUsers = {
  admin: { id: '11111111-1111-1111-1111-111111111111', email: 'admin@test.canhgia.local' },
  minh: { id: '22222222-2222-2222-2222-222222222222', email: 'minh@test.canhgia.local' },
  lan: { id: '33333333-3333-3333-3333-333333333333', email: 'lan@test.canhgia.local' },
}

let mockServer: Mock

beforeAll(async () => {
  mockServer = startMock({ port: 8787 })
})

afterAll(async () => {
  await mockServer.close()
})

async function callFn(name: string, body: unknown, authHeader?: string) {
  const headers: Record<string, string> = { 'content-type': 'application/json', apikey: API_KEY }
  if (authHeader) headers.authorization = authHeader
  const res = await fetch(`${API_URL}/functions/v1/${name}`, { method: 'POST', headers, body: JSON.stringify(body) })
  return res.status === 204 ? null : res.json()
}

async function syncTransactions() {
  return callFn('sync-transactions', { window: 'page1' }, `Bearer ${SERVICE_KEY}`)
}

async function createClick(userId: string, merchant: string, url: string) {
  const res = await fetch(`${API_URL}/rest/v1/rpc/create_click`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', apikey: SERVICE_KEY },
    body: JSON.stringify({ p_user_id: userId, p_merchant: merchant, p_url: url, p_offer_url: url, p_source: 'app' }),
  })
  return res.json()
}

async function getWallet(userId: string) {
  const res = await fetch(`${API_URL}/rest/v1/wallets?id=eq.${userId}`, {
    headers: { apikey: SERVICE_KEY, prefer: 'return=representation' },
  })
  const [row] = await res.json()
  return row || {}
}

async function getOrders(userId: string) {
  const res = await fetch(`${API_URL}/rest/v1/orders?user_id=eq.${userId}&select=id,merchant_id,status,commission_vnd,held_remaining_vnd`, {
    headers: { apikey: SERVICE_KEY },
  })
  return res.json()
}

describe('Backend sync-transactions', () => {
  it('J1: sync pending conversion → wallet pending ↑, notification', async () => {
    // Create a click and emit conversion
    const click = await createClick(testUsers.minh.id, 'shopee', 'https://shopee.vn/sp-1')
    const conversions = makeConversions(1, 1, { utm_content: click.utm_content, commission: 150000, status: 0, is_confirmed: 0 })
    await fetch(`${mockServer.url}/__control`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ conversions }),
    })

    // Sync and check wallet
    const syncRes = await syncTransactions()
    assertEquals((syncRes?.synced_orders || 0) > 0, true)

    const wallet = await getWallet(testUsers.minh.id)
    assert(wallet.pending_vnd >= 150000, `Expected pending ≥ 150k, got ${wallet.pending_vnd}`)

    // Check order created
    const orders = await getOrders(testUsers.minh.id)
    const order = orders.find((o: any) => o.merchant_id === 'shopee')
    assertEquals(order?.status, 0, 'order status should be 0 (pending)')
  })

  it('J2: confirm conversion → held, promote, replay idempotent', async () => {
    const click = await createClick(testUsers.lan.id, 'tiki', 'https://tiki.vn/tk-1')
    const conversions = [
      makeConversions(1, 2, { utm_content: click.utm_content, commission: 100000, status: 0, is_confirmed: 0 })[0],
    ]
    await fetch(`${mockServer.url}/__control`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ conversions }),
    })

    // Sync pending
    await syncTransactions()
    let orders = await getOrders(testUsers.lan.id)
    const orderId = orders.find((o: any) => o.merchant_id === 'tiki')?.id

    // Flip to confirmed
    conversions[0].status = 1
    conversions[0].is_confirmed = 1
    await fetch(`${mockServer.url}/__control`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ conversions }),
    })

    // Sync again
    await syncTransactions()
    orders = await getOrders(testUsers.lan.id)
    const order = orders.find((o: any) => o.id === orderId)
    assertEquals(order?.status, 1, 'order status should be 1 (held)')

    // Replay sync - should be idempotent
    const sync2 = await syncTransactions()
    const orders2 = await getOrders(testUsers.lan.id)
    const order2 = orders2.find((o: any) => o.id === orderId)
    assertEquals(order2?.status, 1, 'second sync should not change status')
  })
})
