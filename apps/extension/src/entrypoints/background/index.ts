import type { Kind, Message, Reply } from '../../lib/messages'
import { pollQr, signInGoogle, signOut, startQr } from './auth'
import { activate, pageInfo, popupData } from './handlers'

async function route(m: Message): Promise<unknown> {
  switch (m.kind) {
    case 'pageInfo': return pageInfo(m.url)
    case 'popupData': return popupData(m.tabUrl)
    case 'activate': return activate(m.tabId, m.merchantId, m.url, m.newTab)
    case 'signInGoogle': return signInGoogle()
    case 'qrStart': return startQr()
    case 'qrPoll': return pollQr()
    case 'signOut': return signOut()
    default: throw new Error('unknown_message')
  }
}

export default defineBackground(() => {
  chrome.runtime.onInstalled.addListener((d) => {
    if (d.reason === 'install') void chrome.tabs.create({ url: chrome.runtime.getURL('/welcome.html') })
  })

  chrome.runtime.onMessage.addListener((raw: Message, sender, respond) => {
    // Only our own pages/content scripts may talk to the router.
    if (sender.id !== chrome.runtime.id) return false
    // content scripts activate their own tab; never trust a tabId they send
    const m = raw.kind === 'activate' && sender.tab?.id ? { ...raw, tabId: sender.tab.id } : raw
    route(m).then(
      (data) => respond({ ok: true, data } as Reply<Kind>),
      (e: unknown) => {
        console.warn('canhgia:', m.kind, e)
        respond({ ok: false, error: e instanceof Error ? e.message : 'error' })
      },
    )
    return true
  })
})
