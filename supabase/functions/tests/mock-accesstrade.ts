// Local AccessTrade stand-in (fixture-backed). Deno.serve on a given port (default 0 = random; phase 11 uses 8787).
// Control: POST /__control {conversions?, feed?, fail?: {path, onCall, status}, linkFail?: boolean}
import campaigns from './fixtures/campaigns.json' with { type: 'json' }
import offers from './fixtures/offers-informations.json' with { type: 'json' }
import datafeeds from './fixtures/datafeeds.json' with { type: 'json' }
import txFixture from './fixtures/transactions.json' with { type: 'json' }

type Row = Record<string, unknown>
export interface Call {
  method: string
  path: string
  params: Record<string, string>
  body: unknown
  at: number
}
interface Fail {
  path: string
  onCall: number
  status: number
}

export interface Mock {
  url: string
  calls: Call[]
  state: { conversions: Row[]; feed: Row[]; fail: Fail | null; linkFail: boolean }
  close(): Promise<void>
}

/** n documented-shape conversions, ids starting at `from`; utm_content `u1c<i>` unless overridden. */
export function makeConversions(n: number, from = 1, over: Row = {}): Row[] {
  return Array.from({ length: n }, (_, i) => ({
    ...txFixture.documented_row,
    conversion_id: from + i,
    transaction_id: `ORD${from + i}`,
    merchant: 'shopee',
    utm_content: `u1c${from + i}`,
    commission: 10000,
    transaction_value: 200000,
    update_time: '2026-09-29T10:00:00Z',
    ...over,
  }))
}

export function startMock(o: { port?: number; clock?: () => number } = {}): Mock {
  const clock = o.clock ?? Date.now
  const calls: Call[] = []
  const state: Mock['state'] = { conversions: [], feed: datafeeds.data as Row[], fail: null, linkFail: false }
  const hit = new Map<string, number>()
  const jr = (b: unknown, status = 200) => new Response(JSON.stringify(b), { status, headers: { 'content-type': 'application/json' } })

  const server = Deno.serve({ port: o.port ?? 0, hostname: '0.0.0.0', onListen: () => {} }, async (req) => {
    const u = new URL(req.url)
    const params = Object.fromEntries(u.searchParams)
    const body = req.method === 'POST' ? await req.json().catch(() => null) : null
    if (u.pathname === '/__control') {
      Object.assign(state, body)
      return jr({ ok: true })
    }
    if (!req.headers.get('authorization')?.startsWith('token ')) return jr({ message: 'Invalid token' }, 401)
    calls.push({ method: req.method, path: u.pathname, params, body, at: clock() })
    const n = (hit.get(u.pathname) ?? 0) + 1
    hit.set(u.pathname, n)
    if (state.fail && state.fail.path === u.pathname && state.fail.onCall === n) return jr({ message: 'limit' }, state.fail.status)

    const page = Number(params.page ?? 1)
    const limit = Number(params.limit ?? 100)
    const slice = (rows: Row[]) => rows.slice((page - 1) * limit, page * limit)
    switch (u.pathname) {
      case '/v1/transactions':
        return jr({ total: state.conversions.length, data: slice(state.conversions) })
      case '/v1/datafeeds':
        return jr({ data: slice(state.feed) })
      case '/v1/offers_informations':
        return jr({ data: slice(offers.data as Row[]) })
      case '/v1/campaigns':
        return jr({ data: campaigns.data, page: 1, total_page: 1 })
      case '/v1/product_link/create': {
        const b = body as { urls?: string[] }
        if (state.linkFail) return jr({ data: { success_link: [], error_link: b.urls ?? [], suspend_url: [] }, success: false })
        return jr({
          data: {
            success_link: [{
              aff_link: 'https://go.example/deep_link/X',
              short_link: 'https://shorten.example/X',
              first_link: null,
              url_origin: 'https://shopee.vn',
            }],
            error_link: [],
            suspend_url: [],
          },
          success: true,
        })
      }
      case '/v2/tiktokshop_product_feeds/create_link':
        if (state.linkFail) return jr({ message: 'fail', status: false })
        return jr({
          data: { aff_url: 'https://go.example/tt/X', aff_short_url: 'https://shorten.example/tt', product_id: 'P' },
          status: true,
        })
      default:
        return jr({ message: 'not found' }, 404)
    }
  })
  return { url: `http://localhost:${server.addr.port}`, calls, state, close: () => server.shutdown() }
}
