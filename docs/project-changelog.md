# Changelog

Derived from `git log`. Versions: app `1.0.0+1` (pubspec), extension `0.1.0`. Nothing is released to any store yet.

## Unreleased (phase 12, 2026-09-30)
- docs: system-architecture, deployment-guide, project-changelog, development-roadmap.
- ci: manual deploy workflows `deploy-{supabase,web,extension,android}.yml` (skip with a warning when secrets are absent).
- web: `/chinh-sach-bao-mat` Vietnamese privacy policy (contact from `NEXT_PUBLIC_SUPPORT_EMAIL`).
- mobile: Android release signing from `android/key.properties` (falls back to debug key when absent).

## Phase 11 - integration + e2e matrix (`bf154f3`, `3e9fcea`, `82c4db4`)
- Deno integration tests (`supabase/tests/integration`), Playwright web/extension e2e, Flutter `integration_test`, `e2e.yml`.
- Harness fixes: JSR imports, OTP login helper via Mailpit, mock AT on 0.0.0.0.
- Known: last recorded run (`plans/reports/tester-260930-0010-*`) had backend sync-cycle/poison-row failing, web e2e 2/16 before the OTP helper fix, extension e2e blocked (needs xvfb/headed), mobile e2e device-only and not run.

## Phases 04-06 - Flutter (`eb9c532`, `1bffb42`, `0904d83`, `93dcc0f`, `4ef1039`, `bc02522`)
- Core: auth (Google + email OTP, Turnstile), router, theme, account, realtime, biometric PIN vault. Shopping: home, link, search, vouchers, compare, price history, watchlist. Wallet: wallet, orders, withdraw, PIN, KYC, missing order, rewards, notifications.
- Review fixes: sign-out cleanup (push token, vault, referral), grants-safe counts, `allowBackup=false`, realtime identical-event delivery, withdraw `request_key` persistence across unknown outcomes, vouchers insert, PIN retry.
- Known: iOS incomplete (xcconfig ids, URL scheme, Associated Domains); Firebase Gradle plugin not wired; reset PIN is "contact support"; KYC `?step=1` on verified user re-submits (S6); auth network errors may show "unknown" (W11) unless fixed - see review.

## Phases 07-09 - web (`98f3ff0`, `f79c09b`, `173e48d`, `8b25274`, `ee6e2d5`)
- Landing (no fake stats), env-driven `.well-known`, admin login + TOTP (aal2), overview, orders + reconciliation + export, cashback rules, withdrawals with local VietQR, users + fraud, complaints.
- Review fixes: bulk-paid semantics, security headers, audit for exports/KYC views, TOTP-enrol gate (`20261003000100_admin_hardening.sql`).
- Known: export `count: exact` per chunk + whole workbook buffered (50k rows cap); `transferRefSchema` accepts any 4-64 chars (DB unique index guards duplicates).

## Phase 10 - extension (`4e4b135`, `d196a08`)
- WXT MV3: cashback bar on 4 merchants, popup, QR-pair login (hardened), create-link with url fallback.
- Review fixes: message trust, IP resolution, FCM token safety.
- Known: Google login uses implicit flow (PKCE preferred); `EXTENSION_ID` placeholder in `config.toml`; resolve-url has no per-user rate limit (short-link SSRF-safe but up to 5 hops x 3 s).

## Phase 03 - Edge + cron (`e7d52e9`)
- `resolve-url, create-link, admin-at-lookup, extension-login, sync-transactions, sync-datafeeds, sync-catalog, send-push`; 13 cron jobs; shared AT token bucket; sub1 attribution fallback.

## Phases 02a/02b - database (`aec408b`, `1e4dbb0`, `3204320`, `307b485`, `a5cb4b3`)
- Schema, RLS, column grants, held -> available ledger, withdrawal claim flow, PIN token, admin gate, reference data, read models, engagement, VIP, risk.
- Review fixes: ledger promotion, ingest, grants, `start_extension_login` null-IP guard.
- Known: admin can re-claim a `processing` withdrawal after 30 min (double payout risk; UI shows claimer); `admin_gate` audit row rolls back with a failing op and `forbidden` attempts are not audited; `set_click_link` no-ops on unknown id.

## Phase 01 - foundation (`a2de1d1`, `787ca71`)
- Monorepo, toolchain, Supabase init, CI, AccessTrade read-only spike (`accesstrade-capability-matrix.md`): 0 of 7 merchants approved, `commission_policies` 404, utm_content round trip untested.
