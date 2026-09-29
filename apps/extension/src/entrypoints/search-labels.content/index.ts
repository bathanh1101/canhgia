import { canInject, findMerchant, pageKind } from '../../lib/merchant-page-detectors'
import { send } from '../../lib/messages'
import { injectLabels } from './labels'
import { parserFor } from './parsers'

export default defineContentScript({
  matches: ['https://*.shopee.vn/*', 'https://*.lazada.vn/*', 'https://*.tiki.vn/*', 'https://*.tiktok.com/*'],
  async main(ctx) {
    let observer: MutationObserver | null = null
    let timer: ReturnType<typeof setTimeout> | undefined

    const stop = () => {
      observer?.disconnect()
      observer = null
    }
    const start = async (url: string) => {
      stop()
      try {
        const info = await send('pageInfo', { url })
        const m = info.merchant ?? findMerchant(url, info.rates)
        const parser = m && canInject(m) && pageKind(m.merchant_id, url) === 'search' ? parserFor(m.merchant_id) : undefined
        if (!m || !parser) return
        const run = () => injectLabels(document, parser, m.max_user_rate_bps)
        run()
        // results render lazily / on scroll; debounce so a busy page is not re-scanned per mutation
        observer = new MutationObserver(() => {
          clearTimeout(timer)
          timer = setTimeout(run, 300)
        })
        observer.observe(document.body, { childList: true, subtree: true })
      } catch (e) {
        console.warn('canhgia: labels disabled', e)
      }
    }

    ctx.onInvalidated(stop)
    void start(location.href)
    ctx.addEventListener(window, 'wxt:locationchange', ({ newUrl }) => void start(newUrl.toString()))
  },
})
