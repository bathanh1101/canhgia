import { test, expect, type Page } from '@playwright/test'
import { pg, seedWithdrawal } from './helpers/db'

const row = (page: Page, amount: number) =>
  page.getByRole('row').filter({ hasText: `${amount.toLocaleString('vi-VN')}đ` })

async function pay(page: Page, amount: number, ref: string) {
  await page.goto('/admin/withdrawals')
  await row(page, amount).getByRole('button', { name: 'Chuyển khoản' }).click()
  const dialog = page.getByRole('dialog')
  await expect(dialog.getByText('Số tài khoản')).toBeVisible()
  const verify = dialog.getByRole('button', { name: 'Xác nhận tên chủ TK khớp' })
  if (await verify.isVisible()) await verify.click()
  await expect(verify).toBeHidden()
  await dialog.getByLabel('Mã giao dịch ngân hàng').fill(ref)
  await dialog.getByRole('button', { name: 'Đã chuyển' }).click()
  return dialog
}

test.describe('J4: admin payout', () => {
  // the pending list is global: clear leftovers so rows are ours only
  test.beforeEach(async () => {
    await pg('withdrawals?status=in.(pending,processing)', { method: 'DELETE' })
  })

  test('overview loads for an aal2 admin', async ({ page }) => {
    await page.goto('/admin/overview')
    await expect(page.getByRole('heading', { name: 'Tổng quan' })).toBeVisible()
  })

  test('claim -> verify holder name -> mark paid', async ({ page }) => {
    const w = await seedWithdrawal(51_000)
    const ref = `FT${Date.now()}`
    const dialog = await pay(page, 51_000, ref)
    await expect(dialog).toBeHidden()
    await expect(page.getByText('Đã đánh dấu đã chuyển khoản')).toBeVisible()
    const [after] = (await pg(`withdrawals?id=eq.${w.id}&select=status,transfer_ref,paid_by`)).body
    expect(after).toMatchObject({ status: 'paid', transfer_ref: ref })
    await expect(row(page, 51_000)).toHaveCount(0) // gone from the pending list
  })

  test('one bank reference cannot pay two withdrawals', async ({ page }) => {
    const ref = `FT-DUP-${Date.now()}`
    const a = await seedWithdrawal(52_000)
    const b = await seedWithdrawal(53_000)
    await expect(await pay(page, 52_000, ref)).toBeHidden()
    await pay(page, 53_000, ref)
    await expect(page.getByText('Mã giao dịch này đã được dùng cho một yêu cầu khác.')).toBeVisible()
    const rows = (await pg(`withdrawals?id=in.(${a.id},${b.id})&select=id,status`)).body as { id: string; status: string }[]
    expect(rows.find((r) => r.id === a.id)?.status).toBe('paid')
    expect(rows.find((r) => r.id === b.id)?.status).toBe('processing') // claimed, still unpaid
  })
})
