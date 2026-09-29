import { defineConfig } from '@playwright/test'

// Needs a build against the local stack first (see e2e/README section in docs/deployment-guide.md):
//   WXT_SUPABASE_URL=http://127.0.0.1:55321 WXT_SUPABASE_PUBLISHABLE_KEY=<anon> WXT_LANDING_URL=http://localhost:3000 pnpm build
export default defineConfig({
  testDir: './e2e',
  workers: 1, // one browser with the extension at a time; specs share the local database
  timeout: 60_000,
  reporter: 'html',
  use: {
    baseURL: process.env.WEB_BASE_URL ?? 'http://localhost:3000',
  },
})
