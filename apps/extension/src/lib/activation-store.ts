import type { Activation } from './types'

const KEY = 'activations'
type Map = Record<string, number>

async function load(): Promise<Map> {
  const raw = (await chrome.storage.local.get(KEY))[KEY]
  return raw && typeof raw === 'object' ? (raw as Map) : {}
}

export async function saveActivation(merchantId: string, hours: number, now = Date.now()): Promise<Activation> {
  const expiresAt = now + hours * 3600 * 1000
  const m = await load()
  // drop expired entries on every write so the map cannot grow
  for (const [k, v] of Object.entries(m)) if (v <= now) delete m[k]
  m[merchantId] = expiresAt
  await chrome.storage.local.set({ [KEY]: m })
  return { merchantId, expiresAt }
}

export async function getActivation(merchantId: string, now = Date.now()): Promise<Activation | null> {
  const expiresAt = (await load())[merchantId]
  return typeof expiresAt === 'number' && expiresAt > now ? { merchantId, expiresAt } : null
}
