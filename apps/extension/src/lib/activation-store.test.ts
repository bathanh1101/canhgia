import { describe, expect, it } from 'vitest'
import { getActivation, saveActivation } from './activation-store'

describe('activation store', () => {
  it('is active until expiresAt, then gone', async () => {
    const a = await saveActivation('shopee', 24, 1_000)
    expect(a.expiresAt).toBe(1_000 + 24 * 3600 * 1000)
    expect(await getActivation('shopee', a.expiresAt - 1)).toEqual(a)
    expect(await getActivation('shopee', a.expiresAt)).toBeNull()
  })
  it('is per merchant and prunes expired entries on write', async () => {
    await saveActivation('lazada', 1, 0)
    await saveActivation('shopee', 24, 10 * 3600 * 1000)
    expect(await getActivation('lazada', 10 * 3600 * 1000)).toBeNull()
    expect(await getActivation('shopee', 10 * 3600 * 1000 + 1)).not.toBeNull()
    expect(await getActivation('tiki')).toBeNull()
  })
})
