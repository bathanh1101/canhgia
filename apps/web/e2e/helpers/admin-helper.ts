import { Page, expect } from '@playwright/test'
import * as OTPAuth from 'otpauth'

const testUsers = {
  admin: { email: 'admin@test.canhgia.local' },
}

const MAILPIT_API_URL = 'http://127.0.0.1:55324/api/v1'
export const TEST_TOTP_SECRET = 'JBSWY3DPEBLW64TMMQ====='

function generateTOTP(secret: string): string {
  const totp = new OTPAuth.TOTP({ secret: OTPAuth.Secret.fromBase32(secret) })
  return totp.generate()
}

/** Fetch 6-digit OTP code from the most recent email to given address via Mailpit API */
async function fetchOTPFromMailpit(email: string): Promise<string> {
  const res = await fetch(`${MAILPIT_API_URL}/messages`)
  const data = (await res.json()) as { messages: Array<{ To: Array<{ Address: string }>; Body: string }> }

  // Find the most recent email to this address
  const msg = data.messages?.find((m) => m.To?.some((t) => t.Address === email))
  if (!msg) throw new Error(`No email found to ${email} in Mailpit`)

  // Extract 6-digit code from body (usually in format like "Your code is: 123456")
  const match = msg.Body.match(/(\d{6})/)
  if (!match) throw new Error(`No 6-digit code found in email body: ${msg.Body}`)
  return match[1]
}

export async function loginAsAdmin(page: Page) {
  await page.goto('/admin/login')

  // Enter email
  await page.fill('input[name="email"]', testUsers.admin.email)
  await page.click('button:has-text("Gửi mã")')

  // Wait for OTP input and fill it
  await expect(page.locator('input[name="otp-code"]')).toBeVisible({ timeout: 5000 })
  const code = await fetchOTPFromMailpit(testUsers.admin.email)
  await page.fill('input[name="otp-code"]', code)
  await page.click('button:has-text("Verify")')

  // Check if on MFA enrollment page
  const url = page.url()
  if (url.includes('/admin/mfa')) {
    // Enroll TOTP on first login
    await enrollTOTP(page, TEST_TOTP_SECRET)
  } else if (url.includes('/admin/mfa-verify')) {
    // Verify TOTP if already enrolled
    await enterTOTP(page, TEST_TOTP_SECRET)
  }

  // Should be on overview
  await expect(page).toHaveURL('/admin/overview', { timeout: 5000 })
}

export async function enrollTOTP(page: Page, secret: string) {
  // Assumes on MFA enroll page; display shows QR code
  const code = generateTOTP(secret)
  await page.fill('input[name="totp-code"]', code)
  await page.click('button:has-text("Verify")')
  await expect(page).toHaveURL('/admin/overview')
}

export async function enterTOTP(page: Page, secret: string) {
  const code = generateTOTP(secret)
  await page.fill('input[name="totp"]', code)
  await page.click('button:has-text("Verify")')
}
