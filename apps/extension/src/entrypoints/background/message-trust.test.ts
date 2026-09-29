import { expect, it } from 'vitest'
import { isAllowed } from './message-trust'

const BASE = 'chrome-extension://abc/'
it('content scripts only get pageInfo/activate; extension pages get everything', () => {
  const page = { url: 'https://shopee.vn/x' }
  const popup = { url: `${BASE}popup.html` }
  for (const k of ['pageInfo', 'activate'] as const) expect(isAllowed(k, page, BASE)).toBe(true)
  for (const k of ['popupData', 'signOut', 'signInGoogle', 'qrStart', 'qrPoll'] as const) {
    expect(isAllowed(k, page, BASE)).toBe(false)
    expect(isAllowed(k, popup, BASE)).toBe(true)
  }
  expect(isAllowed('signOut', {}, BASE)).toBe(false)
  expect(isAllowed('signOut', { url: 'https://evil.test/chrome-extension://abc/' }, BASE)).toBe(false)
})
