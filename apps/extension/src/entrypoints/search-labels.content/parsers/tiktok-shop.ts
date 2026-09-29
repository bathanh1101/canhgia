import type { CardParser } from './types'
import { queryAll } from './types'

export const tiktokShopParser: CardParser = {
  merchantId: 'tiktok_shop',
  cards: (doc) => queryAll(doc, ['[data-e2e="search-product-card"]', '[class*="ProductCard"]', 'a[href*="/product/"]']),
}
