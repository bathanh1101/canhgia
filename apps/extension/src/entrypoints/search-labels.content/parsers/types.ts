export interface CardParser {
  merchantId: string
  /** Result cards on the current search page. Must never throw; unknown layout => []. */
  cards: (doc: Document) => HTMLElement[]
}

/** First selector that yields anything wins, so a redesign that breaks one selector falls through to the next. */
export function queryAll(doc: Document, selectors: string[]): HTMLElement[] {
  for (const s of selectors) {
    try {
      const found = [...doc.querySelectorAll<HTMLElement>(s)]
      if (found.length) return found
    } catch {
      /* invalid selector for this engine: try the next one */
    }
  }
  return []
}
