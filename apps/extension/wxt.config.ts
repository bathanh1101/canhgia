import { defineConfig } from 'wxt'

// Bar/labels inject only on these (plan validation S1); travel merchants are popup-activate only.
const INJECT = [
  'https://*.shopee.vn/*',
  'https://*.lazada.vn/*',
  'https://*.tiki.vn/*',
  'https://*.tiktok.com/*',
]

const SUPABASE = process.env.WXT_SUPABASE_URL ?? 'http://127.0.0.1:55321'

// `wxt prepare` (typecheck) also runs in production mode, so the guard hangs off the real build only.
const REQUIRED_ENV = ['WXT_SUPABASE_URL', 'WXT_SUPABASE_PUBLISHABLE_KEY', 'WXT_LANDING_URL']

export default defineConfig({
  hooks: {
    'build:before': (wxt) => {
      const missing = REQUIRED_ENV.filter((k) => !process.env[k])
      if (wxt.config.mode === 'production' && missing.length) throw new Error(`production build needs env: ${missing.join(', ')}`)
    },
  },
  srcDir: 'src',
  modules: ['@wxt-dev/module-react'],
  manifest: {
    name: 'CanhGia - Hoàn tiền khi mua sắm',
    description: 'Kích hoạt hoàn tiền khi mua sắm trên Shopee, Lazada, Tiki, TikTok Shop.',
    // Fixed key => stable extension id => stable https://<id>.chromiumapp.org/ redirect (see README).
    ...(process.env.WXT_EXTENSION_KEY ? { key: process.env.WXT_EXTENSION_KEY } : {}),
    permissions: ['storage', 'identity', 'activeTab'],
    host_permissions: [...INJECT, `${new URL(SUPABASE).origin}/*`],
    // travel merchants (agoda, traveloka, klook): popup-activate only, matched against the active tab (activeTab); no scripts injected
    optional_host_permissions: ['https://*.agoda.com/*', 'https://*.traveloka.com/*', 'https://*.klook.com/*'],
    icons: { 16: 'icons/16.png', 48: 'icons/48.png', 128: 'icons/128.png' },
    action: { default_title: 'CanhGia' },
  },
})
