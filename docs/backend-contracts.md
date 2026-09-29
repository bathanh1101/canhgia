# Backend contracts (as built by phases 02a / 02b / 03) — consumed by 04–10

Source of truth = SQL in `supabase/migrations/` and `supabase/functions/`. This page is the index; when in doubt read the fn body.

## Error vocabulary (SQL `raise` message = code, `detail` = JSON)
User: `forbidden, rate_limited, account_locked, insufficient_balance, pin_invalid, pin_locked, kyc_required, code_invalid, code_pending, hold_active, daily_cap, invalid_input`.
Admin per-row: `invalid_state, not_claimer, bank_unverified`. Edge extra: `unsupported_url` (422), `merchant_unavailable` (422).
HTTP map (Edge): forbidden/account_locked/pin_*/kyc_required 403 · rate_limited 429 · insufficient_balance/hold_active/daily_cap 409 · code_invalid 410 · code_pending 202 · invalid_input 400.

## Money (02a) — `authenticated` RPC
`verify_pin(p_pin)`, `set_withdraw_pin(p_pin)` (PIN = `^\d{6}$`), `request_withdrawal(...)` (needs pin token 60s single-use; `request_key` idempotent), `submit_kyc(...)`, `add_bank_account(...)` (KYC must be `verified`), `register_device(...)`, `get_extension_login_request(p_code)`, `approve_extension_login(p_code)`, `is_admin()`.
Admin (aal2 + `admins` row): `admin_claim_withdrawal, admin_mark_paid, admin_reject_withdrawals, admin_verify_bank_account, admin_review_kyc, admin_adjust_wallet`. All write `admin_audit_log`.
Tables user may SELECT own rows: `profiles, wallets (Realtime), wallet_ledger, orders, clicks, withdrawals (Realtime), notifications (Realtime), kyc_profiles, bank_accounts, user_devices, push_tokens, referrals`. Admin-only: `user_risk, order_raw, admins, admin_audit_log, fraud_flags, sync_*`.
Money columns: `*_vnd bigint` except `withdrawals.amount`. Rates `*_bps int`. VIP bonus = share of COMMISSION (`vip_tiers.bonus_bps` 0/500/1000/2000). Referral bonus = min(30.000đ, 30% commission).
Settings (`app_settings`): `min_withdraw_vnd, withdraw_daily_cap_vnd, referral_bonus_vnd, click_limit_per_hour, withdraw_eta_text, landing_stats, auto_payout_enabled, auto_payout_limit_vnd`.

## Engagement / read models (02b)
anon+authenticated: `search_offers(p_q, p_merchants text[], p_sort relevance|price_asc|price_desc|cashback_desc, p_limit≤50, p_offset)`, `get_compare(p_group_id)`, `get_price_history(p_group_id, p_days)`, `estimate_cashback(p_merchant_id, p_category_key, p_order_value, p_tier_code)`, `get_merchant_rates()`, `get_public_settings()`; tables `merchants, banks, missions, vip_tiers, vouchers, offers, product_groups, price_snapshots` readable.
authenticated: `touch_activity(), complete_onboarding(), update_profile(p_display_name, p_notification_prefs), bind_referral(p_code), daily_checkin()→(coins,streak), get_mission_progress(), claim_mission(p_code), record_link_share(p_click_id), mark_notifications_read(p_ids[]), submit_missing_order(p_merchant_id, p_order_code, p_purchased_on, p_value, p_image_paths[])→'KN-xxxxxx'`. Direct CRUD: `saved_vouchers` (insert/delete), `watchlist_items` (insert/delete/update target_price_vnd).
admin (aal2): `admin_assign_order, admin_resolve_complaint(p_id, p_decision, p_amount, p_note)` (≥2.000.000đ needs a 2nd approver → `requires_second_approver`), `admin_upsert_cashback_rule, admin_update_vip_tier, admin_set_setting, admin_set_user_lock, admin_update_flag, admin_overview(p_from,p_to), admin_monthly_series(p_months), admin_merchant_mix(p_from,p_to), admin_user_stats(p_days), admin_top_users(p_limit)`.
service_role: `assign_product_groups, evaluate_price_alerts, refresh_vip_tiers, refresh_risk_scores` (+ 02a svc fns; cron in `20261002000100_cron_jobs.sql`).
Dev seed (`supabase/seed.sql`, local only): users `admin@ / minh@ / lan@test.canhgia.local`, Vault secrets `cccd_pepper, project_url, cron_secret`.

## Edge Functions (03) — `POST /functions/v1/<fn>`, header `apikey` always; user fns also `Authorization: Bearer <jwt>`; cron fns `x-cron-secret`. Errors `{error, detail?}`.
| fn | auth | request | 200 |
|---|---|---|---|
| resolve-url | user | `{url}` | `{merchant_id, resolved_url, offer?{id,name,image,price_vnd,product_group_id,cashback_eligible}, estimate{base_rate_bps,vip_rate_bps,cashback_vnd?}\|null, datafeed_enabled}` |
| create-link | user | `{merchant_id, source:'app'\|'extension', url?, device_id?}` | `{click_id, aff_link, short_link, merchant_id, activation_hours, estimate}` (dedupe → stored link) |
| admin-at-lookup | admin aal2 | `{merchant_id, order_code, purchased_on:'YYYY-MM-DD'}` | `{rows:[AT conversions], clicks:[{id,user_id,merchant_id,source,status,utm_content,created_at}]}` |
| extension-login | anon | `{action:'start', client_secret_hash}` → `{code, expires_at}`; `{action:'poll', code, client_secret}` → 202 pending / 200 `{token_hash}` / 410 | client then `auth.verifyOtp({token_hash, type:'magiclink'})`; poll ≥ 2 s |
| sync-transactions / sync-datafeeds / sync-catalog / send-push | cron | `{window}` / `{mode}` / `{what}` / `{}` | counters |
Edge secrets: `ACCESSTRADE_TOKEN, ACCESSTRADE_BASE_URL, CRON_SECRET, FCM_PROJECT_ID, FCM_SERVICE_ACCOUNT_JSON`. Mock AT server for tests: `supabase/functions/tests/mock-accesstrade.ts` (`startMock({port})`, control `POST /__control`).

## Local stack quirk
Port 54322 is held by another local project → `supabase start` from repo root fails. Scratch workdir `/tmp/claude-1000/wd` (config copy, ports 553xx, `migrations/tests/templates/seed.sql` symlinked) is the working stack: API `http://127.0.0.1:55321`, DB `postgresql://postgres:postgres@127.0.0.1:55322/postgres`. `supabase gen types typescript --db-url <that>` works without the CLI stack.
