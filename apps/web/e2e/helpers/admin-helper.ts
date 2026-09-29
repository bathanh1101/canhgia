import { Page, expect } from '@playwright/test'
import * as OTPAuth from 'otpauth'

const testUsers = {
  admin: { email: 'admin@test.canhgia.local', password: 'admin_pwd' },
}

function generateTOTP(secret: string): string {
  const totp = new OTPAuth.TOTP({ secret: OTPAuth.Secret.fromBase32(secret) })
  return totp.generate()
}

export async function loginAsAdmin(page: Page) {
  await page.goto('/admin/login')
  await page.fill('input[name="email"]', testUsers.admin.email)
  await page.fill('input[name="password"]', testUsers.admin.password)
  await page.click('button[type="submit"]')
  // May redirect to MFA if enrolled
}

export async function enrollTOTP(page: Page, secret: string) {
  // Assumes on MFA enroll page; fetches QR and shows input for code
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

export const TEST_TOTP_SECRET = 'JBSWY3DPEBLW64TMMQ======'
