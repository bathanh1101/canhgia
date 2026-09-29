import { defineConfig, devices } from '@playwright/test'

const WEB_BASE_URL = process.env.WEB_BASE_URL ?? 'http://localhost:3000'

export default defineConfig({
  testDir: './e2e',
  globalSetup: './e2e/global-setup.ts',
  fullyParallel: false, // specs share one database (wallets, pending lists), so they run one at a time
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 1 : 0,
  workers: 1,
  reporter: 'html',
  use: {
    baseURL: WEB_BASE_URL,
    trace: 'on-first-retry',
    storageState: 'e2e/.auth/admin.json', // aal2 admin session from global-setup; unauthenticated specs override it
  },

  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
  ],

  webServer: {
    command: 'pnpm start',
    url: WEB_BASE_URL,
    reuseExistingServer: !process.env.CI,
  },
})
