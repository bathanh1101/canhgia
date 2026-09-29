import { type Page, expect } from '@playwright/test'
import * as OTPAuth from 'otpauth'
import fs from 'node:fs'
import path from 'node:path'

export const MAILPIT = process.env.MAILPIT_URL ?? 'http://127.0.0.1:55324'
export const ADMIN_EMAIL = 'admin@test.canhgia.local'
export const SHOPPER_EMAIL = 'minh@test.canhgia.local'
export const AUTH_DIR = path.join(__dirname, '..', '.auth')
export const ADMIN_STATE = path.join(AUTH_DIR, 'admin.json')
const TOTP_FILE = path.join(AUTH_DIR, 'totp-secret.txt')

export const totpNow = (secret: string) => new OTPAuth.TOTP({ secret: OTPAuth.Secret.fromBase32(secret) }).generate()

async function latestCodeFor(email: string): Promise<string> {
  for (let i = 0; i < 30; i++) {
    const list = (await (await fetch(`${MAILPIT}/api/v1/messages`)).json()) as { messages: { ID: string; To: { Address: string }[] }[] }
    const hit = list.messages.find((m) => m.To.some((t) => t.Address === email)) // newest first
    if (hit) {
      const msg = (await (await fetch(`${MAILPIT}/api/v1/message/${hit.ID}`)).json()) as { Text: string }
      const code = msg.Text.match(/\b(\d{6})\b/)?.[1]
      if (code) return code
    }
    await new Promise((r) => setTimeout(r, 500))
  }
  throw new Error(`no OTP mail for ${email} in Mailpit`)
}

/** Email OTP step of /admin/login (Turnstile test key auto-passes). Ends on /admin/mfa with an aal1 session. */
export async function emailOtpLogin(page: Page, email: string) {
  await fetch(`${MAILPIT}/api/v1/messages`, { method: 'DELETE' }) // so the code we read is the one we just triggered
  await page.goto('/admin/login')
  await page.locator('#email').fill(email)
  const send = page.getByRole('button', { name: 'Gửi mã qua email' })
  await expect(send).toBeEnabled({ timeout: 20_000 }) // enabled once Turnstile yields a token
  await send.click()
  await expect(page.locator('#code')).toBeVisible({ timeout: 15_000 })
  await page.locator('#code').fill(await latestCodeFor(email))
  await page.getByRole('button', { name: 'Đăng nhập', exact: true }).click()
  await page.waitForURL(/\/admin\/(mfa|login\?e=forbidden)/) // non-admins are bounced by /admin/mfa itself
}

/** Full admin login -> aal2 on /admin/overview. First run enrols TOTP and keeps the secret in e2e/.auth. */
export async function loginAsAdmin(page: Page) {
  await emailOtpLogin(page, ADMIN_EMAIL)
  const enrol = page.getByRole('button', { name: 'Thiết lập ứng dụng xác thực' })
  let secret: string
  if (await enrol.isVisible()) {
    await enrol.click()
    const hint = await page.getByText(/Hoặc nhập khóa:/).innerText()
    secret = hint.replace(/^.*:\s*/, '').trim()
    fs.mkdirSync(AUTH_DIR, { recursive: true })
    fs.writeFileSync(TOTP_FILE, secret)
  } else {
    if (!fs.existsSync(TOTP_FILE)) throw new Error('admin already has a TOTP factor but e2e/.auth/totp-secret.txt is missing: reset the DB (supabase db reset)')
    secret = fs.readFileSync(TOTP_FILE, 'utf8').trim()
  }
  await page.locator('#totp').fill(totpNow(secret))
  await page.getByRole('button', { name: 'Xác nhận' }).click()
  await page.waitForURL('**/admin/overview')
}
