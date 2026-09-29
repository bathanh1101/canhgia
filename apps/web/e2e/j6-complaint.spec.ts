import { test, expect, type Page } from '@playwright/test'
import { ageRecentClicks, ingestConversion, pg, seedComplaint, USERS } from './helpers/db'

async function openComplaint(page: Page, code: string) {
  await page.goto('/admin/complaints')
  await page.getByRole('link', { name: code }).click()
  await expect(page.getByRole('heading', { name: 'Chi tiết khiếu nại' })).toBeVisible()
}
async function resolve(page: Page, amount: number, note: string) {
  await page.getByRole('button', { name: 'Xử lý khiếu nại' }).click()
  const d = page.getByRole('dialog')
  await d.getByLabel(/Tiền hoàn/).fill(String(amount))
  await d.getByLabel(/Ghi chú/).fill(note)
  await d.getByRole('button', { name: 'Duyệt' }).click()
  return d
}
const wallet = () => pg(`wallets?user_id=eq.${USERS.minh}&select=pending_vnd,held_vnd,available_vnd`).then((r) => r.body[0] as Record<string, number>)
const total = (w: Record<string, number>) => w.pending_vnd + w.held_vnd + w.available_vnd

test.describe('J6: complaints', () => {
  test('approve missing order -> manual order credited to the user', async ({ page }) => {
    const c = await seedComplaint(`KN${Date.now()}`)
    const before = total(await wallet())
    await openComplaint(page, c.public_code)
    await expect(await resolve(page, 50_000, 'Đã đối chiếu với ảnh chụp')).toBeHidden()
    const [rep] = (await pg(`missing_order_reports?id=eq.${c.id}&select=status,resolution_amount_vnd,resolved_order_id`)).body
    expect(rep).toMatchObject({ status: 'approved', resolution_amount_vnd: 50_000 })
    expect(rep.resolved_order_id).toBeTruthy()
    expect(total(await wallet())).toBe(before + 50_000)
  })

  test('same order code claimed by another user via AT -> order_claim_conflict flag, no silent reassign', async ({ page }) => {
    const code = `CLM${Date.now()}`
    const c = await seedComplaint(code)
    await openComplaint(page, c.public_code)
    await expect(await resolve(page, 40_000, 'Duyệt thủ công cho minh')).toBeHidden()
    // AT later reports the same order code, attributed to lan's click
    await ageRecentClicks()
    const click = (await pg('rpc/create_click', {
      method: 'POST',
      body: { p_user_id: USERS.lan, p_merchant_id: 'shopee', p_origin_url: 'https://shopee.vn/x', p_resolved_url: `https://shopee.vn/x-${code}`, p_offer_id: null, p_source: 'app', p_device_hash: null },
    })).body[0]
    await ingestConversion({ transaction_id: code, utm_content: click.utm_content })
    const flags = (await pg(`fraud_flags?type=eq.order_claim_conflict&user_id=eq.${USERS.minh}&select=status&order=id.desc&limit=1`)).body
    expect(flags[0]?.status).toBe('open')
    const manual = (await pg(`orders?transaction_id_norm=eq.${code}&select=user_id,source`)).body
    expect(manual.map((o: { user_id: string }) => o.user_id)).toContain(USERS.minh)
    await page.goto('/admin/users')
    await expect(page.getByText('Tranh chấp đơn hàng').first()).toBeVisible()
  })

  test('amount above 2.000.000đ needs a second approver', async ({ page }) => {
    const c = await seedComplaint(`BIG${Date.now()}`, 3_000_000)
    const before = total(await wallet())
    await openComplaint(page, c.public_code)
    await expect(page.getByRole('dialog')).toBeHidden()
    await page.getByRole('button', { name: 'Xử lý khiếu nại' }).click()
    await page.getByRole('dialog').getByLabel(/Tiền hoàn/).fill('2500000')
    await expect(page.getByText(/cần admin thứ 2 xác nhận/)).toBeVisible()
    await page.getByRole('dialog').getByLabel(/Ghi chú/).fill('Đơn giá trị lớn')
    await page.getByRole('dialog').getByRole('button', { name: 'Duyệt' }).click()
    await expect(page.getByText('Chờ admin thứ 2')).toBeVisible()
    const [rep] = (await pg(`missing_order_reports?id=eq.${c.id}&select=status,first_approved_amount,resolved_order_id`)).body
    expect(rep).toMatchObject({ status: 'reviewing', first_approved_amount: 2_500_000, resolved_order_id: null })
    expect(total(await wallet())).toBe(before) // nothing credited yet
  })
})
