import { chromium, type FullConfig } from '@playwright/test'
import fs from 'node:fs'
import { ADMIN_STATE, AUTH_DIR, loginAsAdmin } from './helpers/admin-helper'

// One real OTP + TOTP login per run (local GoTrue caps emails per hour); specs reuse the aal2 session.
export default async function globalSetup(config: FullConfig) {
  fs.mkdirSync(AUTH_DIR, { recursive: true })
  const browser = await chromium.launch()
  const page = await browser.newPage({ baseURL: config.projects[0].use.baseURL })
  await loginAsAdmin(page)
  await page.context().storageState({ path: ADMIN_STATE })
  await browser.close()
}
