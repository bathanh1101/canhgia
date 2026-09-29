import fs from 'node:fs'
import path from 'node:path'
import { test, expect } from './fixtures'

const API = 'http://127.0.0.1:55321'
const SERVICE = process.env.SUPABASE_SERVICE_ROLE_KEY ??
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU'
const ANON = process.env.SUPABASE_ANON_KEY ??
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0'
const JWT_SECRET = process.env.JWT_SECRET ?? 'super-secret-jwt-token-with-at-least-32-characters-long'
const MINH = '22222222-2222-2222-2222-222222222222'

import { createHmac } from 'node:crypto'
const b64 = (o: object) => Buffer.from(JSON.stringify(o)).toString('base64url')
function userJwt(sub: string) {
  const now = Math.floor(Date.now() / 1000)
  const d = `${b64({ alg: 'HS256', typ: 'JWT' })}.${b64({ aud: 'authenticated', role: 'authenticated', sub, aal: 'aal1', iat: now, exp: now + 3600 })}`
  return `${d}.${createHmac('sha256', JWT_SECRET).update(d).digest('base64url')}`
}

/** What the phone app does after scanning: approve the newest pending code as this user. */
async function approveNewestPendingCode() {
  const list = await fetch(`${API}/rest/v1/extension_login_codes?status=eq.pending&select=code&order=created_at.desc&limit=1`, {
    headers: { apikey: SERVICE, authorization: `Bearer ${SERVICE}` },
  }).then((r) => r.json())
  expect(list, 'popup should have started a QR session').toHaveLength(1)
  const res = await fetch(`${API}/rest/v1/rpc/approve_extension_login`, {
    method: 'POST',
    headers: { apikey: ANON, authorization: `Bearer ${userJwt(MINH)}`, 'content-type': 'application/json' },
    body: JSON.stringify({ p_code: list[0].code }),
  })
  expect(res.status).toBeLessThan(300)
}

test.describe('J7: extension login + activation', () => {
  test.beforeEach(async () => {
    // start is limited to 5 codes / IP / 10 min
    await fetch(`${API}/rest/v1/extension_login_codes?code=not.is.null`, { method: 'DELETE', headers: { apikey: SERVICE, authorization: `Bearer ${SERVICE}` } })
  })

  test('welcome page explains the 3 steps and offers login', async ({ context, extensionId }) => {
    const page = await context.newPage()
    await page.goto(`chrome-extension://${extensionId}/welcome.html`)
    await expect(page.getByRole('heading', { name: 'Cài đặt thành công!' })).toBeVisible()
    await expect(page.getByRole('button', { name: 'Quét mã bằng app CanhGia' })).toBeVisible()
  })

  test('popup logged out shows the login prompt', async ({ context, extensionId }) => {
    const page = await context.newPage()
    await page.goto(`chrome-extension://${extensionId}/popup.html`)
    await expect(page.getByRole('heading', { name: 'Đăng nhập để nhận hoàn tiền' })).toBeVisible()
  })

  test('QR pairing: QR shown -> phone approves -> popup signs in', async ({ context, extensionId }) => {
    const page = await context.newPage()
    await page.goto(`chrome-extension://${extensionId}/popup.html`)
    await page.getByRole('button', { name: 'Quét mã bằng app CanhGia' }).click()
    await expect(page.getByRole('img', { name: 'Mã QR đăng nhập' })).toBeVisible()
    await approveNewestPendingCode()
    // poll runs every 2 s; on approval the popup reloads into the logged-in view
    await expect(page.getByRole('heading', { name: 'Đăng nhập để nhận hoàn tiền' })).toBeHidden({ timeout: 15_000 })
    await expect(page.getByText('Khả dụng')).toBeVisible()
    await page.getByRole('button', { name: 'Đăng xuất' }).click()
    await expect(page.getByRole('heading', { name: 'Đăng nhập để nhận hoàn tiền' })).toBeVisible()
  })

  // needs the mock AccessTrade server on :8787 (edge functions call it for the deep link)
  test('logged in: bar on a Shopee product page -> activate -> deep link opened, click recorded', async ({ context, extensionId }) => {
    const popup = await context.newPage()
    await popup.goto(`chrome-extension://${extensionId}/popup.html`)
    await popup.getByRole('button', { name: 'Quét mã bằng app CanhGia' }).click()
    await expect(popup.getByRole('img', { name: 'Mã QR đăng nhập' })).toBeVisible()
    await approveNewestPendingCode()
    await expect(popup.getByText('Khả dụng')).toBeVisible({ timeout: 15_000 })

    const html = fs.readFileSync(path.join(import.meta.dirname, 'fixtures', 'shopee-product.html'), 'utf8')
    const page = await context.newPage()
    await page.route('https://shopee.vn/**', (r) => r.fulfill({ contentType: 'text/html', body: html }))
    const url = 'https://shopee.vn/Tai-nghe-Sony-WH-1000XM5-i.111.222'
    await page.goto(url)
    const bar = page.getByRole('region', { name: 'CanhGia' })
    await expect(bar).toBeVisible({ timeout: 15_000 })
    await page.route('https://go.example/**', (r) => r.fulfill({ contentType: 'text/html', body: 'ok' }))
    await bar.getByRole('button', { name: 'Kích hoạt hoàn tiền' }).click()
    // activation sends the tab through the affiliate deep link (mock AT answers with go.example)
    await page.waitForURL('https://go.example/deep_link/X', { timeout: 15_000 })
    // create_link dedupes per user+merchant+url inside the activation window, so assert the stored click, not a count
    expect(await latestExtensionClick()).toMatchObject({ status: 'ok', aff_link: 'https://go.example/deep_link/X' })
  })
})

async function latestExtensionClick() {
  const r = await fetch(`${API}/rest/v1/clicks?user_id=eq.${MINH}&source=eq.extension&select=status,aff_link&order=id.desc&limit=1`, {
    headers: { apikey: SERVICE, authorization: `Bearer ${SERVICE}` },
  })
  return (await r.json())[0]
}
