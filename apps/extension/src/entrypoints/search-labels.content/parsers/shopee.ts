import type { CardParser } from './types'
import { queryAll } from './types'

// Card = the product anchor's list item; selectors are best-effort and may miss after a redesign (labels then degrade silently).
export const shopeeParser: CardParser = {
  merchantId: 'shopee',
  cards: (doc) => queryAll(doc, ['li.shopee-search-item-result__item', '[data-sqe="item"]', 'a[href*="-i."]']),
}
