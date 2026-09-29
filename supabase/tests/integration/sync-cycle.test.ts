// Backend integration: sync-transactions cycle (J1/J2). Real function + real DB, AccessTrade replaced by the mock.
import { afterAll, beforeAll, describe, it } from 'jsr:@std/testing@1.0.0/bdd'
import { assert, assertEquals } from 'jsr:@std/assert@1.0.0'
import { makeConversions, type Mock, startMock } from '../../functions/tests/mock-accesstrade.ts'
import { createClick, fn, getOrder, getWallet, rest, setConversions, syncRecent, USERS } from './helpers.ts'

let mock: Mock
beforeAll(() => {
  mock = startMock({ port: 8787 })
})
afterAll(() => mock.close())

// conversion ids unique per run so reruns never collide with rows from earlier runs
const base = Date.now()

describe('sync-transactions', () => {
  it('rejects a call without x-cron-secret', async () => {
    const r = await fn('sync-transactions', { window: 'recent' })
    assertEquals(r.status, 403)
  })

  it('rejects an unknown window', async () => {
    const r = await fn('sync-transactions', { window: 'page1' }, { 'x-cron-secret': Deno.env.get('CRON_SECRET') ?? '' })
    assertEquals(r.status, 400)
  })

  it('J1: pending conversion -> order inserted, wallet pending up, notification', async () => {
    const click = await createClick(USERS.minh, 'shopee', 'https://shopee.vn/sp-1')
    const before = (await getWallet(USERS.minh)).pending_vnd
    await setConversions(makeConversions(1, base, { utm_content: click.utm_content, commission: 150000, status: 0, is_confirmed: 0 }))

    const r = await syncRecent()
    assertEquals(r.body.inserted, 1)
    assertEquals(r.body.errors, 0)

    const order = await getOrder(base)
    assertEquals([order.merchant_id, order.user_id, order.at_status, order.credit_state], ['shopee', USERS.minh, 0, 'pending'])
    assertEquals(order.user_cashback_vnd > 0, true)
    assertEquals((await getWallet(USERS.minh)).pending_vnd, before + order.user_cashback_vnd)

    const n = (await rest(`notifications?user_id=eq.${USERS.minh}&type=eq.order&data->>order_id=eq.${order.id}&select=title,data`)).body
    assertEquals([n.length, n[0]?.data.state], [1, 'pending'])
  })

  it('J2: confirm -> credited/held, replay is idempotent', async () => {
    const click = await createClick(USERS.lan, 'tiki', 'https://tiki.vn/tk-1')
    const conv = makeConversions(1, base + 1, { utm_content: click.utm_content, merchant: 'tiki', commission: 100000, update_time: '2026-09-29T10:00:00Z' })
    await setConversions(conv)
    await syncRecent()
    assertEquals((await getOrder(base + 1)).credit_state, 'pending')

    const confirmed = conv.map((c) => ({ ...c, status: 1, is_confirmed: 1, update_time: '2026-09-29T11:00:00Z' }))
    await setConversions(confirmed)
    const r2 = await syncRecent()
    assertEquals(r2.body.updated, 1)
    const order = await getOrder(base + 1)
    assertEquals(order.credit_state, 'credited')
    const wallet = await getWallet(USERS.lan)

    const r3 = await syncRecent() // same page again
    assert(r3.body.skipped >= 1 && r3.body.updated === 0, `replay must skip, got ${JSON.stringify(r3.body)}`)
    assertEquals(await getWallet(USERS.lan), wallet)
    assertEquals((await getOrder(base + 1)).user_cashback_vnd, order.user_cashback_vnd)
  })
})
