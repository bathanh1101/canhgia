import { formatRate } from '../../lib/format'
import type { CardParser } from './parsers/types'

const ATTR = 'data-canhgia-label'
const STYLE = 'display:inline-block;margin:4px 0;padding:2px 8px;border-radius:999px;background:#d1fae5;color:#047857;font:700 12px system-ui,sans-serif'

/** Idempotent: a card that already carries a label (or contains one) is skipped. Returns how many labels were added. */
export function injectLabels(doc: Document, parser: CardParser, rateBps: number): number {
  let added = 0
  try {
    for (const card of parser.cards(doc)) {
      if (card.hasAttribute(ATTR) || card.querySelector(`[${ATTR}]`)) continue
      const el = doc.createElement('span')
      el.setAttribute(ATTR, '1')
      el.setAttribute('style', STYLE)
      el.textContent = `Hoàn đến ${formatRate(rateBps)}`
      card.setAttribute(ATTR, '1')
      card.appendChild(el)
      added++
    }
  } catch (e) {
    console.warn('canhgia: label injection skipped', e)
  }
  return added
}
