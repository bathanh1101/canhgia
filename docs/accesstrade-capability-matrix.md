# AccessTrade capability matrix

**Status: spike BLOCKED - no AccessTrade token in this environment. No API was called.** Every live-verified column is `AMBIGUOUS (pending AT token)`; go/no-go = `pending`. Sample files in `docs/accesstrade-samples/` are shaped from research-01, not live responses (`_source` field). Re-run the spike per phase-01 once a token exists.

Static facts (research-01, EXTRACTED unless noted): auth header `Authorization: token <T>`; link `POST /v1/product_link/create`; `GET /v1/transactions` and `/v1/order-list` 10 req/min; datafeed `GET /v1/datafeeds` max limit 200; `GET /v1/campaigns`, `/v1/offers_informations` INFERRED.

| Merchant | campaign key | link_api (`product_link/create`) | tiktok api | datafeed (Y/N, count) | vouchers | cashback allowed (T&C) | activation_hours | hold_days | sample commission bps | go/no-go |
|---|---|---|---|---|---|---|---|---|---|---|
| Shopee | shopee | Y (`product_link/create`) | N/A | AMBIGUOUS; typically not in open datafeed; count AMBIGUOUS (pending AT token) | AMBIGUOUS (pending AT token) | AMBIGUOUS (pending AT token) | AMBIGUOUS (pending AT token) | AMBIGUOUS (pending AT token) | AMBIGUOUS (pending AT token) | pending |
| Lazada | lazada | Y | N/A | Y in docs example; count AMBIGUOUS (pending AT token) | AMBIGUOUS (pending AT token) | AMBIGUOUS (pending AT token) | AMBIGUOUS (pending AT token) | AMBIGUOUS (pending AT token) | AMBIGUOUS (pending AT token) | pending |
| TikTok Shop | tiktok shop | separate TikTok API (v1/v2 create link) - not read | Y (v1/v2, must read docs) | TikTok product search v1/v2; count AMBIGUOUS (pending AT token) | AMBIGUOUS (pending AT token) | AMBIGUOUS (pending AT token) | AMBIGUOUS (pending AT token) | AMBIGUOUS (pending AT token) | AMBIGUOUS (pending AT token) | pending |
| Tiki | tikivn | Y | N/A | AMBIGUOUS (pending AT token); count AMBIGUOUS (pending AT token) | AMBIGUOUS (pending AT token) | AMBIGUOUS (pending AT token) | AMBIGUOUS (pending AT token) | AMBIGUOUS (pending AT token) | AMBIGUOUS (pending AT token) | pending |
| Agoda | agoda | no doc evidence; campaign default link | N/A | AMBIGUOUS (pending AT token); count AMBIGUOUS (pending AT token) | AMBIGUOUS (pending AT token) | AMBIGUOUS (pending AT token) | AMBIGUOUS (pending AT token) | AMBIGUOUS (pending AT token) | AMBIGUOUS (pending AT token) | pending |
| Traveloka | traveloka | no doc evidence; campaign default link | N/A | AMBIGUOUS (pending AT token); count AMBIGUOUS (pending AT token) | AMBIGUOUS (pending AT token) | AMBIGUOUS (pending AT token) | AMBIGUOUS (pending AT token) | AMBIGUOUS (pending AT token) | AMBIGUOUS (pending AT token) | pending |
| Klook | klook | no doc evidence; campaign default link | N/A | AMBIGUOUS (pending AT token); count AMBIGUOUS (pending AT token) | AMBIGUOUS (pending AT token) | AMBIGUOUS (pending AT token) | AMBIGUOUS (pending AT token) | AMBIGUOUS (pending AT token) | AMBIGUOUS (pending AT token) | pending |

## utm_content round-trip

`not run` - needs a real low-value purchase via a link with `utm_content=u1c1`, then check the `/v1/transactions` row. Gates phase 03 only (wait <= 7 days; else sub1 fallback + unmatched queue, flag AMBIGUOUS).

## Open items for the spike
- campaign list (`approval=successful`) and per-campaign commission policies
- TikTok Shop create-link v1 vs v2
- cookie window (-> activation_hours), recommended hold (-> hold_days), cashback/incentive-traffic clauses per campaign T&C
- transactions: max `limit`, whether since/until filters create or update time, `sub1` returned or not
