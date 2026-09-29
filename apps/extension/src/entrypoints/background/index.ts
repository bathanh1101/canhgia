import type { Kind, Message, Reply } from '../../lib/messages'
import { pollQr, signInGoogle, signOut, startQr } from './auth'
import { activate, pageInfo, popupData } from './handlers'
import { isAllowed, isExtensionPage } from './message-trust'
import { cachedPageInfo, clearPageInfoCache } from './page-info-cache'

async function route(m: Message, sender: chrome.runtime.MessageSender, fromPage: boolean): Promise<unknown> {
  switch (m.kind) {
    case 'pageInfo': {
      // content scripts: the URL is the browser-reported tab URL, never a caller-supplied one
      if (!fromPage) return pageInfo(m.url)
      if (sender.tab?.id === undefined || !sender.tab.url) throw new Error('no_tab')
      const { id, url } = sender.tab
      return cachedPageInfo(id, url, () => pageInfo(url))
    }
    case 'popupData': return popupData(m.tabUrl)
    case 'activate': clearPageInfoCache(); return activate(m.tabId, m.merchantId, m.url, m.newTab)
    case 'signInGoogle': clearPageInfoCache(); return signInGoogle()
    case 'qrStart': return startQr()
    case 'qrPoll': clearPageInfoCache(); return pollQr()
    case 'signOut': clearPageInfoCache(); return signOut()
    default: throw new Error('unknown_message')
  }
}

export default defineBackground(() => {
  // chrome.storage.local (auth tokens) is readable from content scripts by default; Chrome 102+ can restrict it
  void chrome.storage.local.setAccessLevel?.({ accessLevel: 'TRUSTED_CONTEXTS' }).catch((e: unknown) => console.warn('canhgia: storage access level', e))
  chrome.runtime.onInstalled.addListener((d) => {
    if (d.reason === 'install') void chrome.tabs.create({ url: chrome.runtime.getURL('/welcome.html') })
  })

  chrome.runtime.onMessage.addListener((raw: Message, sender, respond) => {
    // Only our own pages/content scripts may talk to the router, and content scripts only for their own kinds.
    if (sender.id !== chrome.runtime.id || !isAllowed(raw.kind, sender, chrome.runtime.getURL(''))) return false
    const fromPage = !isExtensionPage(sender, chrome.runtime.getURL(''))
    // content scripts activate their own tab; never trust a tabId they send
    const m = raw.kind === 'activate' && fromPage && sender.tab?.id ? { ...raw, tabId: sender.tab.id } : raw
    route(m, sender, fromPage).then(
      (data) => respond({ ok: true, data } as Reply<Kind>),
      (e: unknown) => {
        console.warn('canhgia:', m.kind, e)
        respond({ ok: false, error: e instanceof Error ? e.message : 'error' })
      },
    )
    return true
  })
})
