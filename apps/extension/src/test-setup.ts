import { beforeEach } from 'vitest'

// Minimal in-memory chrome.storage.local for unit tests.
let store: Record<string, unknown> = {}
beforeEach(() => {
  store = {}
  ;(globalThis as unknown as { chrome: unknown }).chrome = {
    storage: {
      local: {
        get: async (k: string) => (k in store ? { [k]: store[k] } : {}),
        set: async (o: Record<string, unknown>) => void Object.assign(store, o),
        remove: async (k: string) => void delete store[k],
      },
    },
  }
})
