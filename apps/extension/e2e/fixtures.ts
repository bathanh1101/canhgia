import { test as base, chromium, type BrowserContext } from '@playwright/test'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const EXT = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', '.output', 'chrome-mv3')

/** Fresh persistent context with the built extension loaded (new headless mode supports MV3 service workers). */
export const test = base.extend<{ context: BrowserContext; extensionId: string }>({
  // eslint-disable-next-line no-empty-pattern
  context: async ({}, use) => {
    const context = await chromium.launchPersistentContext('', {
      channel: 'chromium',
      args: [`--disable-extensions-except=${EXT}`, `--load-extension=${EXT}`, '--headless=new'],
    })
    await use(context)
    await context.close()
  },
  extensionId: async ({ context }, use) => {
    const sw = context.serviceWorkers()[0] ?? (await context.waitForEvent('serviceworker'))
    await use(new URL(sw.url()).host)
  },
})
export { expect } from '@playwright/test'
