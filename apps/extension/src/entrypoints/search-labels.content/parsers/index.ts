import { lazadaParser } from './lazada'
import { shopeeParser } from './shopee'
import { tikiParser } from './tiki'
import { tiktokShopParser } from './tiktok-shop'
import type { CardParser } from './types'

const ALL: CardParser[] = [shopeeParser, lazadaParser, tikiParser, tiktokShopParser]
export const parserFor = (merchantId: string): CardParser | undefined => ALL.find((p) => p.merchantId === merchantId)
