// Backend integration: a bad AT row never blocks its page; stale pages never regress state; admin-at-lookup gate + result.
import { afterAll, beforeAll, describe, it } from 'jsr:@std/testing@1.0.0/bdd'
import { assertEquals } from 'jsr:@std/assert@1.0.0'
import { makeConversions, type Mock, startMock } from '../../functions/tests/mock-accesstrade.ts'
import { createClick, fn, getOrder, resetLimits, setConversions, syncRecent, USERS, userJwt } from './helpers.ts'

let mock: Mock
beforeAll(() => {
  mock = startMock({ port: 8787 })
})
afterAll(() => mock.close())

const base = Date.now() * 10 // ids from a disjoint range vs sync-cycle, ms resolution so back-to-back runs never collide

describe('poison row + stale page', () => {
  it('invalid row is counted as error, valid neighbour still ingested', async () => {
    const click = await createClick(USERS.minh, 'shopee', 'https://shopee.vn/sp-2')
    const good = makeConversions(1, base, { utm_content: click.utm_content })[0]
    const bad = makeConversions(1, base + 1, { status: 99 })[0]
    await setConversions([bad, good])
    const r = await syncRecent()
    assertEquals([r.body.inserted, r.body.errors], [1, 1])
    assertEquals((await getOrder(base))?.credit_state, 'pending')
    assertEquals(await getOrder(base + 1), undefined)
  })

  it('older update_time for a known conversion is skipped, newer state kept', async () => {
    const click = await createClick(USERS.minh, 'shopee', 'https://shopee.vn/sp-3')
    const fresh = makeConversions(1, base + 2, { utm_content: click.utm_content, commission: 80000, update_time: '2026-09-29T12:00:00Z' })
    await setConversions(fresh)
    await syncRecent()
    await setConversions(fresh.map((c) => ({ ...c, commission: 1000, update_time: '2026-09-01T00:00:00Z' })))
    const r = await syncRecent()
    assertEquals(r.body.skipped, 1)
    assertEquals((await getOrder(base + 2)).commission_vnd, 80000)
  })
})

describe('admin-at-lookup', () => {
  const body = { merchant_id: 'shopee', order_code: `ORD${base + 2}`, purchased_on: '2026-09-29' }

  it('no bearer token -> 401', async () => {
    assertEquals((await fn('admin-at-lookup', body)).status, 401)
  })

  it('non-admin user -> 403', async () => {
    assertEquals((await fn('admin-at-lookup', body, { authorization: `Bearer ${await userJwt(USERS.minh, 'aal2')}` })).status, 403)
  })

  it('admin with aal1 -> 403 (aal2 required)', async () => {
    assertEquals((await fn('admin-at-lookup', body, { authorization: `Bearer ${await userJwt(USERS.admin, 'aal1')}` })).status, 403)
  })

  it('admin aal2 -> matching AT row and its click', async () => {
    await resetLimits()
    const r = await fn('admin-at-lookup', body, { authorization: `Bearer ${await userJwt(USERS.admin, 'aal2')}` })
    assertEquals(r.status, 200)
    assertEquals(r.body.rows.map((x: { transaction_id: string }) => x.transaction_id), [body.order_code])
    assertEquals(r.body.clicks.length, 1)
    assertEquals(r.body.clicks[0].user_id, USERS.minh)
  })
})
