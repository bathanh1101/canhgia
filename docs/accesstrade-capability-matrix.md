# AccessTrade capability matrix

Spike run 2026-09-29, GET only, real token. Tags: **[L]** EXTRACTED live · **[D]** EXTRACTED from docs page · **[I]** INFERRED · **[A]** AMBIGUOUS.
Samples: `docs/accesstrade-samples/*.json` (sanitized, `_source` set). Full narrative: `plans/reports/researcher-260929-2125-accesstrade-spike.md`.

## Headline (read this first)
1. **Account is approved for only 2 campaigns** [L]: Lazada Malaysia (6867977378089718296), AccessTrade Referral (6136638414227853852). **None of the 7 target merchants is approved**; all are `approval=unregistered` [L]. Nobody can create a link until approvals land (manual for Lazada/Agoda; Shopee, Tiki, TikTok, Klook, Traveloka: apply in dashboard).
2. Use the cashback-specific campaigns where they exist: **Lazada Cashback**, **Tiki CashBack** (new-customer first order only). Lazada KOL and TIKI (CPS) T&C redirect cashback publishers to those.
3. Documented `GET /v1/commission_policies` returns **404** [L]; commission comes from the campaign `description.commission_policy` HTML text instead.
4. `/v1/transactions` returns `total:0` (no conversions yet) [L]; utm_content round-trip untestable until a real order.

## Merchant matrix
| Merchant | campaign_id (best fit) | approval | link ok | link_api | datafeed (Y/N, count) | vouchers |
|---|---|---|---|---|---|---|
| Shopee | 4751584435713464237 "Shopee Việt Nam Smartlink" [L] | unregistered [L] | not run (POST deferred to user) | product_link [I] (docs list it under generic `/v1/product_link/create`) | Y 12,555, fresh (updated 2026-09-29) [L] | 7,643 [L] |
| Lazada | 5249638763776692551 "Lazada Cashback" (alt 5087153089503673507 "Lazada Việt Nam") [L] | unregistered, manual approval via Google form [L] | not run (POST deferred to user) | product_link [I] | Y 1,055,719 but STALE (update_time 2021-09-15) [L] | 0 [L] |
| TikTok Shop | 6648523843406889655 "TIKTOK SHOP CPS" [L] | unregistered [L] | not run (POST deferred to user) | tiktok_shop [D] `POST /v2/tiktokshop_product_feeds/create_link`; campaign text: links made via Product Link tab are NOT tracked [L] | N (0 for tiktok.com / shop.tiktok.com / campaign=tiktok_cps) [L]; product search is a separate v1/v2 API, not run | 0 [L] |
| Tiki | 6023573823797709038 "Tiki CashBack" (alt 4348614231480407268 "TIKI (CPS)") [L] | unregistered [L] (TIKI CPS text: auto-approve [D-text]) | not run (POST deferred to user) | product_link [I] | Y 51,711, fresh [L] | 109 [L] |
| Agoda | 6817930100651517825 "Agoda APAC" [L] | unregistered; manual, only pubs with >50 ATSP [L-text] | not run (POST deferred to user) | campaign_default [I] | N (0) [L] | 0 [L] |
| Traveloka | 6654251588167732819 "Traveloka Partnerize" [L] | unregistered [L] | not run (POST deferred to user) | campaign_default [I] | Y 4,677 but STALE (2022-07-11) [L] | 0 [L] |
| Klook | 4704521809526929067 "Klook - SIM, Vé Tham Quan..." [L] | unregistered [L] | not run (POST deferred to user) | campaign_default [I] | N (0) [L] | 0 [L] |

## Policy matrix
`activation_hours` = cookie window from T&C text (API `cookie_duration` disagrees for Lazada/Tiki: 2592000 s vs "7 ngày" in text; text used, flagged). `hold_days`: T&C never states one; default 30 applied unless evidence noted.

| Merchant | cashback allowed | activation_hours | hold_days | sample commission bps | go/no-go |
|---|---|---|---|---|---|
| Shopee | AMBIGUOUS: Smartlink T&C silent on cashback. Sibling `Shopee MCN`: "Chiến dịch này không dành cho các publisher có hình thức chạy là cashback" [L]. Brand campaigns (Kotex/Sachi/Leafy) have separate "... Cashback" variants [L]. Also bans "tự mua hàng để nhận hoa hồng" | 168 (7d) [L-text] | 30 default; evidence 45-60 (docs example click→confirm 55d; "lên đơn sau 24h") [D][A] | new customer 2400 (cap 30,000 VND/order), existing 180 [L-text] | CONDITIONAL: apply, ask AT AM in writing whether cashback is allowed on Smartlink |
| Lazada | Y: "Chiến dịch này dành cho publisher chạy mô hình Cashback" (Lazada Cashback intro) [L-text] | 168 (text) vs 720 (API) [A] | 30 default [A]; orders appear after 24h; first order per click only ("Chỉ ghi nhận hoa hồng cho đơn hàng đầu tiên") | 350 weekday / 700 sale day base (max 19,444 VND) [L-text] | GO: apply via Google form (manual) |
| TikTok Shop | AMBIGUOUS: silent on cashback; anti-fraud policy 01/07/2026 bans self-purchase, "nhờ bạn bè/người thân đặt hàng", excessive link sharing [L-text] | 336 (14d); link expires after 100 days [L-text] | 30 default [A]; paid ~T+1 on 18th/25th [L-text] | up to 2000 (max_com 20%); per-product rate, docs example 1500 [L-text][D] | CONDITIONAL: gate on AT written OK; link must come from pub2 product-feeds tool/v2 API |
| Tiki | Y for `Tiki CashBack` (dedicated, new customers' first order, CPS) [L-text]; TIKI (CPS): "Đối với các Publisher chạy hình thức Cashback, vui lòng chạy đúng chiến dịch dành riêng" [L-text] | 168 (7d), no-reoccur [L-text] | ~45-60: "thanh toán vào ngày 18 tháng T+2" [L-text]; use 45 (deviates from 30 default) | base 70-700 by category (fashion 700, FMCG 420, baby 70), cap 42,000 VND; CashBack campaign fixed up to 150,000 VND per new customer [L-text] | GO: apply to Tiki CashBack |
| Agoda | AMBIGUOUS (no clause) | 24 (1d) [L-text] | 30 default [A] | 420 (hotel only) [L-text] | NO-GO for now: manual approval, >50 ATSP required; cookie 1 day |
| Traveloka | AMBIGUOUS (no clause) | 336 (14d) [L-text] | 30 default [A]; travel usually after stay [I] | 315 hotel/activities, 32 domestic flight, 69 intl flight (ex-VAT) [L-text] | CONDITIONAL: datafeed stale; VN-account users only |
| Klook | AMBIGUOUS: orders using codes other than AT-provided are not commissioned [L-text] | 720 (30d) [L-text] | 30 default [A]; avg approval rate 70% [L-text] | 350 (gift card/special 140) [L-text] | CONDITIONAL: no own vouchers usable; low approval rate |

## Transactions endpoint
Live: `GET /v1/transactions?since=2026-06-01T00:00:00Z&until=2026-09-29T23:59:59Z&limit=N` → HTTP 200 `{"total":0,"data":[]}` [L].
- `limit`: 100, 300, 1000, 100000, 0, -1 all HTTP 200, no error; empty result so cap is **unproven** [A]. Docs: default 100, max not stated [D]. Plan on 100.
- Time window: 2025-01-01 → today accepted (no 31-day cap seen) [L]. `since` alone (no `until`) accepted. Bad date → `{"message":"Unknown string format","success":false}` [L].
- Which field since/until filters (transaction_time vs update_time): **not determinable** (no rows) [A]. Docs do not say [D]. Re-check after first order.
- Fields [D, not live]: id, transaction_id, conversion_id, merchant, status (0 hold/pending, 1 approved, 2 rejected), is_confirmed, click_time, transaction_time, update_time, confirmed_time, transaction_value, commission, product_*, utm_source/medium/campaign/content/term, conversion_platform, customer_type, is_brand_bonus, reason_rejected, click_url, `_extra`. sub1..sub5: not in documented fields [D].
- `GET /v1/order-list`: HTTP 500 `{"message":"sales date range must be less than 31 days.","status":"fail"}` for wider windows [L]; ≤29-day window OK (0 rows), limit 300/301/1000 accepted (unproven) [L].
- utm_content round-trip: `not run (needs real purchase)`. Note: Shopee/TikTok/Tiki T&C ban self-purchase for commission and reject "tự share đơn của chính mình" (Tiki) → a self-test order may be rejected; confirm with AT before buying.

## Rate limits observed
- Sequential GETs at ≤1 req/s (~75 calls) → no 429, no rate-limit headers in any response (only CORS + nginx headers) [L].
- One deliberate burst of 12 back-to-back `/v1/transactions` calls → `200 200 200 200 429 429 200 200 200 429 200 429` [L]: 429 enforced, consistent with documented 10 req/min [D]. 429 body/headers were not captured; no Retry-After known [A].
- Other limits: `/v1/campaigns` max limit 50 (`{"message":"Max limited is 50"}`); `/v1/offers_informations` max 100 (`limit range [100..0]`); `/v1/datafeeds` 200 accepted [L].

## Deferred: link creation (request shapes; user runs, POST)
Auth for all: `Authorization: token <ACCESSTRADE_TOKEN>`, `Content-Type: application/json`.
1. Generic (Shopee, Lazada, Tiki, travel): `POST https://api.accesstrade.vn/v1/product_link/create` [D]
   `{"campaign_id":"<id above>","urls":["https://shopee.vn/<product-url>"],"utm_source":"canhgia","utm_content":"u1c1","sub1":"c1"}`
   → `{"data":{"success_link":[{"aff_link","short_link","first_link","url_origin"}],"error_link":[],"suspend_url":[]},"success":true}`. Unapproved campaign → expect url in `error_link`/`suspend_url` [I].
2. TikTok Shop v2 [D]: `POST https://api.accesstrade.vn/v2/tiktokshop_product_feeds/create_link`
   `{"product_url":"https://vt.tiktok.com/<code>/","utm_source":"canhgia","utm_content":"u1c1","sub1":"c1"}` → `{"data":{"aff_url","aff_short_url","product_commission":{"amount","currency","rate"},"product_id",...},"status":true}`. v1 also exists (`create-link-v1`), not read.
3. Travel merchants (Agoda, Traveloka, Klook): no per-URL evidence; try (1) with `urls` omitted → campaign default link [D-research-01].
4. Then: buy one low-value item via the link (after AT confirms self-purchase policy), poll `/v1/transactions` in 24-72h, check `utm_content`.
5. Shape files: `docs/accesstrade-samples/product-link-create.json` (`_source: docs shape, POST not run`).
