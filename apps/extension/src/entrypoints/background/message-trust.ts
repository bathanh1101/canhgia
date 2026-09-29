import type { Kind } from '../../lib/messages'

/** Content scripts run inside merchant pages: they get only what the bar/labels/reminder need. */
const CONTENT_KINDS: ReadonlySet<Kind> = new Set<Kind>(['pageInfo', 'activate'])

/** Popup/welcome pages carry the extension origin as sender.url; a content script's sender.url is the host page. */
export const isExtensionPage = (sender: { url?: string }, base: string): boolean => !!sender.url?.startsWith(base)

export const isAllowed = (kind: Kind, sender: { url?: string }, base: string): boolean =>
  isExtensionPage(sender, base) || CONTENT_KINDS.has(kind)
