import type { CardParser } from './types'
import { queryAll } from './types'

export const lazadaParser: CardParser = {
  merchantId: 'lazada',
  cards: (doc) => queryAll(doc, ['[data-qa-locator="product-item"]', '[data-tracking="product-card"]', '.Bm3ON']),
}
