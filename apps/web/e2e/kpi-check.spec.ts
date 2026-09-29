import { test, expect } from '@playwright/test'
import { pg } from './helpers/db'

const VN = 7 * 3600_000 // Asia/Ho_Chi_Minh, no DST
const day = (ms: number) => new Date(ms + VN).toISOString().slice(0, 10)
const vnd = (n: number) => `${n.toLocaleString('vi-VN')}đ`

test('overview KPI cards equal an independent sum over orders', async ({ page }) => {
  const to = day(Date.now())
  const from = day(Date.now() - 300 * 86_400_000)
  const lo = Date.parse(`${from}T00:00:00+07:00`)
  const hi = Date.parse(`${to}T00:00:00+07:00`) + 86_400_000

  const orders = (await pg('orders?select=order_time,created_at,credit_state,value_vnd,commission_vnd&limit=10000')).body as
    { order_time: string | null; created_at: string; credit_state: string; value_vnd: number; commission_vnd: number }[]
  const inRange = orders.filter((o) => {
    const t = Date.parse(o.order_time ?? o.created_at)
    return t >= lo && t < hi
  })
  const sum = (f: (o: (typeof inRange)[number]) => boolean, k: 'value_vnd' | 'commission_vnd') =>
    inRange.filter(f).reduce((a, o) => a + Number(o[k]), 0)
  const expected = {
    GMV: sum((o) => ['pending', 'credited'].includes(o.credit_state), 'value_vnd'),
    'Hoa hồng từ sàn': sum((o) => o.credit_state === 'credited', 'commission_vnd'),
    'Hoa hồng chờ duyệt': sum((o) => o.credit_state === 'pending', 'commission_vnd'),
  }
  expect(inRange.length).toBeGreaterThan(0) // the check is vacuous on an empty DB

  await page.goto(`/admin/overview?from=${from}&to=${to}`)
  for (const [label, value] of Object.entries(expected)) {
    const card = page.locator('div[title]').filter({ has: page.getByText(label, { exact: true }) }).first()
    await expect(card, label).toContainText(vnd(value))
  }
})

test('orders table: status filter narrows the list and the count in the header', async ({ page }) => {
  await page.goto('/admin/orders')
  const count = async () => Number((await page.getByText(/đơn khớp bộ lọc/).innerText()).match(/(\d+)/)![1])
  const all = await count()
  await page.getByLabel('Trạng thái').selectOption({ label: 'Đã cộng tiền' })
  await page.getByRole('button', { name: 'Lọc' }).click()
  await page.waitForURL(/credit_state=|status=|state=/)
  const credited = await count()
  expect(credited).toBeLessThan(all)
  const want = (await pg('orders?credit_state=eq.credited&select=id')).body.length
  expect(credited).toBe(want)
})
