import { test, expect } from '@playwright/test'
import ExcelJS from 'exceljs'
import { ingestConversion, pg, USERS } from './helpers/db'

test.describe('J5: reconciliation', () => {
  test('unmatched order -> assign user -> credited once', async ({ page }) => {
    const conv = await ingestConversion()
    expect(conv.status).toBe('unmatched')

    const q = () => pg(`orders?conversion_id=eq.${conv.id}&select=id,user_id,credit_state,user_cashback_vnd`).then((r) => r.body[0])
    const wallet = () => pg(`wallets?user_id=eq.${USERS.lan}&select=pending_vnd`).then((r) => r.body[0].pending_vnd as number)
    const before = await wallet()
    expect(await q()).toMatchObject({ user_id: null, credit_state: 'none' })

    await page.goto(`/admin/orders?unmatched=1`)
    const row = page.getByRole('row').filter({ hasText: conv.code })
    await row.getByRole('button', { name: 'Gán user' }).click()
    const dialog = page.getByRole('dialog')
    await dialog.getByLabel('Tìm người dùng').fill('lan@test')
    await dialog.getByRole('button', { name: 'Tìm', exact: true }).click()
    await dialog.getByRole('button', { name: /lan@test\.canhgia\.local/ }).click()
    await dialog.getByRole('button', { name: 'Gán', exact: true }).click()
    await page.getByRole('button', { name: 'Gán đơn' }).click() // confirm dialog
    await expect(page.getByRole('dialog')).toHaveCount(0)

    const after = await q()
    expect(after).toMatchObject({ user_id: USERS.lan, credit_state: 'pending' })
    expect(after.user_cashback_vnd).toBeGreaterThan(0)
    expect(await wallet()).toBe(before + after.user_cashback_vnd) // credited once, not twice

    // AT re-delivers the same conversion later (now matched): still one order, no double credit
    await ingestConversion({ conversion_id: conv.id, update_time: new Date(Date.now() + 1000).toISOString() })
    expect((await pg(`orders?conversion_id=eq.${conv.id}&select=id`)).body).toHaveLength(1)
    expect(await wallet()).toBe(before + after.user_cashback_vnd)
  })

  test('Excel export has one data row per order matching the filter', async ({ page }) => {
    await page.goto('/admin/orders')
    const total = Number((await page.getByText(/đơn khớp bộ lọc/).innerText()).match(/(\d+)/)![1])
    const [download] = await Promise.all([page.waitForEvent('download'), page.getByRole('link', { name: 'Xuất Excel' }).click()])
    const wb = new ExcelJS.Workbook()
    await wb.xlsx.readFile(await download.path())
    expect(wb.worksheets[0].rowCount - 1).toBe(total) // minus header row
  })
})
