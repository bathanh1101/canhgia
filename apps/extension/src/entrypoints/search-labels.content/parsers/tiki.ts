import type { CardParser } from './types'
import { queryAll } from './types'

export const tikiParser: CardParser = {
  merchantId: 'tiki',
  cards: (doc) => queryAll(doc, ['a.product-item', '[data-view-id="product_list_item"]', '[class*="product-item"]']),
}
