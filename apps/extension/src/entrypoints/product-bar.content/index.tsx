import { createRoot, type Root } from 'react-dom/client'
import '../../assets/ui.css'
import { BarContainer } from './bar-container'

export default defineContentScript({
  matches: ['https://*.shopee.vn/*', 'https://*.lazada.vn/*', 'https://*.tiki.vn/*', 'https://*.tiktok.com/*'],
  cssInjectionMode: 'ui',
  async main(ctx) {
    let root: Root | null = null
    let dismissed = false
    const render = (url: string) => root?.render(dismissed ? null : <BarContainer key={url} url={url} onClose={() => { dismissed = true; render(url) }} />)

    const ui = await createShadowRootUi(ctx, {
      name: 'canhgia-bar',
      position: 'inline',
      anchor: 'body',
      append: 'first',
      onMount: (container) => {
        root = createRoot(container)
        render(location.href)
        return root
      },
      onRemove: (r) => r?.unmount(),
    })
    ui.mount()
    // SPA navigation: re-evaluate the page kind; a new URL re-arms a dismissed bar
    ctx.addEventListener(window, 'wxt:locationchange', ({ newUrl }) => {
      dismissed = false
      render(newUrl.toString())
    })
  },
})
