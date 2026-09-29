import { test, expect } from '@playwright/test'
import { ADMIN_EMAIL, SHOPPER_EMAIL, emailOtpLogin } from './helpers/admin-helper'
import { pg, rpc, USERS, userJwt, mustOk } from './helpers/db'

test.describe('unauthenticated', () => {
  test.use({ storageState: { cookies: [], origins: [] } })

  for (const path of ['/admin', '/admin/overview', '/admin/orders', '/admin/withdrawals']) {
    test(`${path} -> 307 to /admin/login`, async ({ request }) => {
      const res = await request.get(path, { maxRedirects: 0 })
      expect(res.status()).toBe(307)
      expect(new URL(res.headers().location, 'http://x').pathname).toBe('/admin/login')
    })
  }

  test('browser lands on the login form, not the page', async ({ page }) => {
    await page.goto('/admin/overview')
    await expect(page).toHaveURL(/\/admin\/login$/)
    await expect(page.getByRole('button', { name: 'Gửi mã qua email' })).toBeVisible()
  })

  test('export endpoint answers 401 JSON', async ({ request }) => {
    const res = await request.get('/api/admin/orders-export', { maxRedirects: 0 })
    expect(res.status()).toBe(401)
  })
})

test.describe('sessions below aal2', () => {
  test.use({ storageState: { cookies: [], origins: [] } })

  test('admin with only the email OTP (aal1) is sent to the TOTP step', async ({ page }) => {
    await emailOtpLogin(page, ADMIN_EMAIL)
    await expect(page).toHaveURL(/\/admin\/mfa$/)
    await page.goto('/admin/overview')
    await expect(page).toHaveURL(/\/admin\/mfa$/)
  })

  test('non-admin shopper cannot enrol or reach /admin', async ({ page }) => {
    await emailOtpLogin(page, SHOPPER_EMAIL)
    await expect(page).toHaveURL(/\/admin\/login\?e=forbidden/)
    await page.goto('/admin/overview')
    await expect(page).not.toHaveURL(/\/admin\/overview/)
  })
})

test.describe('database privacy (shopper JWT)', () => {
  const jwt = userJwt(USERS.minh)
  test('private columns are unreadable, public ones are', async () => {
    expect((await pg('orders?select=id,credit_state&limit=1', { jwt })).status).toBe(200)
    for (const q of ['orders?select=commission_vnd', 'wallet_ledger?select=created_by', 'withdrawals?select=risk_level']) {
      const r = await pg(q, { jwt })
      expect(r.status, q).toBeGreaterThanOrEqual(400)
      expect(r.body.code, q).toBe('42501')
    }
  })

  test('admin RPCs refuse a non-admin', async () => {
    const r = await rpc('admin_overview', { p_from: '2026-01-01', p_to: '2026-12-31' }, jwt)
    expect(r.status).toBeGreaterThanOrEqual(400)
  })

  test('search_offers never returns more than 50 rows', async () => {
    const rows = Array.from({ length: 60 }, (_, i) => ({
      external_product_id: `cap-${i}`, name: `Zzcapprobe san pham ${i}`, price: 100000 + i, shop_name: 'E2E', url: `https://shopee.vn/cap-${i}`,
    }))
    await mustOk(rpc('upsert_offers', { p_merchant_id: 'shopee', p_rows: rows }))
    const r = await rpc('search_offers', { p_q: 'zzcapprobe', p_limit: 500, p_offset: 0 }, jwt)
    expect(r.status).toBe(200)
    expect(r.body).toHaveLength(50)
  })
})
