import { beforeEach, expect, it, vi } from 'vitest'
import type { PageInfo } from '../../lib/messages'
import { cachedPageInfo, clearPageInfoCache, PAGE_INFO_TTL_MS } from './page-info-cache'

const info = {} as PageInfo
beforeEach(clearPageInfoCache)

it('shares one load per tab+url within the TTL, reloads after it', async () => {
  const load = vi.fn(() => Promise.resolve(info))
  await Promise.all([cachedPageInfo(1, 'u', load, 0), cachedPageInfo(1, 'u', load, 5), cachedPageInfo(1, 'u', load, 10)])
  expect(load).toHaveBeenCalledTimes(1)
  await cachedPageInfo(2, 'u', load, 10)
  await cachedPageInfo(1, 'u', load, PAGE_INFO_TTL_MS + 1)
  expect(load).toHaveBeenCalledTimes(3)
})

it('does not keep failures and clear() drops entries', async () => {
  const bad = vi.fn(() => Promise.reject(new Error('x')))
  await expect(cachedPageInfo(1, 'u', bad, 0)).rejects.toThrow()
  const ok = vi.fn(() => Promise.resolve(info))
  await cachedPageInfo(1, 'u', ok, 1)
  clearPageInfoCache()
  await cachedPageInfo(1, 'u', ok, 2)
  expect(ok).toHaveBeenCalledTimes(2)
})
