# Deployment guide

Hướng dẫn chi tiết bằng tiếng Việt (chạy local từng app, test/E2E, deploy từng bước): [`run-and-deploy-guide.md`](run-and-deploy-guide.md).

Status: nothing deployed yet. No Supabase cloud project, Vercel, Play/Apple/CWS accounts, domain, Resend, Firebase or Google OAuth clients existed when phase 12 was prepared. Everything below is ready for a human to run. Never commit secrets (`.env*`, keystores, `key.properties`, `env/prod.json` are gitignored).

## Order (matters)
1. Accounts + clients (Google, Firebase, Turnstile, Resend, domain).
2. Supabase project: secrets -> Vault -> functions -> `db push` -> backfill -> auth config -> first admin.
3. Vercel web -> `.well-known` fingerprints.
4. Android AAB (release gate) -> Play internal. Extension zip -> CWS unlisted. iOS best-effort.
5. Go-live checklist (bottom).

## Env matrix
| App | Var | Where | Value |
|---|---|---|---|
| web | `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | Vercel | project URL + publishable/anon key. Never service-role |
| web | `NEXT_PUBLIC_TURNSTILE_SITE_KEY` | Vercel | real site key |
| web | `WEB_BASE_URL`, `APP_BASE_URL` | Vercel | public origin (`https://<x>.vercel.app` until domain) |
| web | `NEXT_PUBLIC_{PLAY,APPSTORE,CWS}_URL` | Vercel | store links; button hidden when unset |
| web | `ANDROID_PACKAGE_NAME`, `ANDROID_SHA256_FINGERPRINTS` (comma list) | Vercel | `io.canhgia.app` + Play App Signing SHA-256 (+ upload key SHA-256 for sideload) |
| web | `APPLE_TEAM_ID`, `IOS_BUNDLE_ID` | Vercel | Team ID + bundle id (iOS only) |
| web | `NEXT_PUBLIC_SUPPORT_EMAIL` | Vercel | contact shown on `/chinh-sach-bao-mat`; unset = "use in-app support" text |
| extension | `WXT_SUPABASE_URL`, `WXT_SUPABASE_PUBLISHABLE_KEY`, `WXT_LANDING_URL` | build env (required, prod build throws without) | prod values |
| extension | `WXT_EXTENSION_KEY` | build env | base64 public key => stable id |
| mobile | `env/prod.json` via `--dart-define-from-file` | local/CI secret `MOBILE_ENV_JSON` | keys of `env/example.json`: `SUPABASE_URL, SUPABASE_ANON_KEY, APP_BASE_URL, GOOGLE_WEB_CLIENT_ID, GOOGLE_IOS_CLIENT_ID, TURNSTILE_SITE_KEY, TURNSTILE_TEST_TOKEN(empty), FCM_ENABLED=true` |
| mobile | `APP_LINK_HOST` | `android/gradle.properties` (default `canhgia.vn`) | host of `APP_BASE_URL` |
| edge | `ACCESSTRADE_TOKEN, ACCESSTRADE_BASE_URL, CRON_SECRET, FCM_PROJECT_ID, FCM_SERVICE_ACCOUNT_JSON` | `supabase secrets` | see below |
| vault | `project_url, cron_secret, cccd_pepper` | SQL | see below |
| auth | `TURNSTILE_SECRET`, `SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_ID/SECRET` | only for local `config.toml` `env()`; hosted = dashboard | |

## 1. Supabase (region ap-southeast-1)
Free plan is not enough for real users (Edge timeouts, pg_cron/pg_net load): use Pro before launch.
```
supabase login && supabase link --project-ref <ref>
# 1 Edge secrets
supabase secrets set ACCESSTRADE_TOKEN=... ACCESSTRADE_BASE_URL=https://api.accesstrade.vn \
  CRON_SECRET=$(openssl rand -hex 32) FCM_PROJECT_ID=... FCM_SERVICE_ACCOUNT_JSON="$(cat sa.json | tr -d '\n')"
# 2 Vault (SQL editor; BEFORE db push so cron never runs blind). cron_secret == CRON_SECRET above
select vault.create_secret('https://<ref>.supabase.co', 'project_url');
select vault.create_secret('<CRON_SECRET>', 'cron_secret');
select vault.create_secret('<openssl rand -hex 32>', 'cccd_pepper');   -- never rotate casually: id_number_hmac depends on it
# 3 functions, then migrations (cron migration is last by timestamp). NEVER --include-seed
supabase functions deploy
supabase db push
```
Same steps automated by `.github/workflows/deploy-supabase.yml` (secrets `SUPABASE_ACCESS_TOKEN, SUPABASE_DB_PASSWORD, SUPABASE_PROJECT_REF`; for `set_secrets` also `ACCESSTRADE_TOKEN, CRON_SECRET, FCM_SERVICE_ACCOUNT_JSON, FCM_PROJECT_ID`). Vault is never set by CI.
- Extensions `pg_cron`, `pg_net`, `vault` must be enabled (dashboard) if the migration reports missing.
- Reference data (merchants, tiers, banks, settings) comes from migration `20261001002000`; `seed.sql` (test users `@test.canhgia.local`) never runs.
- Backfill: cron `datafeeds-backfill` self-completes (10 min ticks). Check `sync_state`; manual kick: `curl -X POST https://<ref>.supabase.co/functions/v1/sync-datafeeds -H "apikey: <anon>" -H "x-cron-secret: <CRON_SECRET>" -d '{"mode":"backfill"}'`.
- Verify: `select count(*) from cron.job` = 13; `select job,last_error from sync_state` has no `vault_missing`; `tx_recent` `last_success_at` < 30 min; `sync_errors` last 24 h = 0 or triaged; `select merchant_id,count(*) from offers group by 1` > 0 for every `datafeed_enabled` merchant; `select count(*) from auth.users where email like '%@test.canhgia.local'` = 0.
- Do NOT `supabase config push`: `config.toml` holds local URLs (`site_url=http://localhost:3000`) and would overwrite hosted auth. Configure auth in the dashboard.

### Auth (dashboard)
- Site URL = web origin. Redirect URLs: `<WEB_BASE_URL>`, `<WEB_BASE_URL>/auth/callback`, `https://<EXTENSION_ID>.chromiumapp.org/`, and `io.canhgia.app://login-callback` only if a redirect flow is added (currently unused).
- Google provider: Web client id/secret (same web client id as `GOOGLE_WEB_CLIENT_ID`). Clients: Web; Android (package `io.canhgia.app` + SHA-1 of the **Play App Signing** key and the upload key); iOS (bundle id). Skip nonce check stays off.
- Captcha: Cloudflare Turnstile, prod secret (site key in web + mobile env).
- MFA: TOTP enrol + verify on. Email: custom SMTP (Resend; default Supabase SMTP is heavily rate limited); OTP length 6, expiry 600; use template `supabase/templates/magic-link.html` as the "Magic link" template (subject `Mã đăng nhập CanhGia`). Resend: verify domain (SPF/DKIM) before real users; onboarding sender only for tests.
- Rate limits: raise `email_sent` from the local value (2/h) to a real limit.

### First admin (out of band)
```
insert into public.admins(user_id, created_by) select id, id from auth.users where email = '<admin>';
```
User must have signed in once. Admin logs in at `/admin/login` (email OTP) then enrols TOTP at `/admin/mfa`; `is_admin()` requires aal2, so nothing works before enrolment. Lost TOTP: a second admin deletes the factor (`auth.mfa_factors` row), user re-enrols. Keep >= 2 admins.

## 2. Web (Vercel)
Import repo, Root Directory `apps/web`, install at repo root (pnpm workspace), Node 24. Set env matrix vars. CLI alternative: `.github/workflows/deploy-web.yml` (`target` preview|production; secrets `VERCEL_TOKEN, VERCEL_ORG_ID, VERCEL_PROJECT_ID`).
- After Play upload: fill `ANDROID_SHA256_FINGERPRINTS`, redeploy, check `https://<host>/.well-known/assetlinks.json` (empty `[]` until both vars set) and AASA.
- `/chinh-sach-bao-mat` = privacy policy URL for Play, App Store, CWS.
- Domain swap later (canhgia.vn): add domain in Vercel + DNS, change `WEB_BASE_URL/APP_BASE_URL`, `WXT_LANDING_URL`, mobile `APP_BASE_URL` + `APP_LINK_HOST`, Supabase Site URL/redirects, Resend domain; redeploy web; ship new app/extension builds (they embed the host). No code change.

## 3. Extension (Chrome Web Store, Unlisted)
1. One time: `openssl genrsa -out key.pem 2048`; `openssl rsa -in key.pem -pubout -outform DER | base64 -w0` -> `WXT_EXTENSION_KEY` (keep key.pem offline). Id is then stable; add `https://<id>.chromiumapp.org/` to Supabase redirect URLs and replace the `EXTENSION_ID` placeholder in `supabase/config.toml` (local only).
2. `deploy-extension.yml` builds `wxt zip` artifact (secrets `WXT_SUPABASE_URL, WXT_SUPABASE_PUBLISHABLE_KEY, WXT_LANDING_URL, WXT_EXTENSION_KEY`). Local: same env + `pnpm --filter ./apps/extension zip` -> `.output/*.zip`.
3. CWS dashboard ($5 dev account): upload zip, visibility Unlisted, privacy policy URL = `<WEB_BASE_URL>/chinh-sach-bao-mat`, disclosure: reads product price and URL on Shopee/Lazada/Tiki/TikTok pages, stores login session, no browsing history. Permissions are minimal (`storage, identity, activeTab` + 4 hosts).
4. Bump `version` in `apps/extension/package.json` per upload. Set the listing URL into `NEXT_PUBLIC_CWS_URL`.

## 4. Android (release gate)
1. Upload keystore: `keytool -genkeypair -v -keystore upload.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000`. Keep offline + backed up.
2. `apps/mobile/android/app/build.gradle.kts` reads `android/key.properties` (`storeFile, storePassword, keyAlias, keyPassword`); absent = debug key (local builds only, Play rejects).
3. Build: `cd apps/mobile && flutter build appbundle --release --dart-define-from-file=env/prod.json` -> `build/app/outputs/bundle/release/app-release.aab`. CI: `deploy-android.yml` (secrets `ANDROID_KEYSTORE_BASE64` = `base64 -w0 upload.jks`, `ANDROID_KEYSTORE_PASSWORD, ANDROID_KEY_ALIAS, ANDROID_KEY_PASSWORD, MOBILE_ENV_JSON`). Bump `version:` in `pubspec.yaml` (`x.y.z+build`) each upload.
4. Play Console ($25): create app `io.canhgia.app`, enrol in Play App Signing, upload AAB to Internal testing, add testers, privacy policy URL, Data safety form (email, device id, KYC images, bank account; encrypted in transit; deletion on request).
5. Take SHA-256/SHA-1 from Play Console > App signing: SHA-1 -> Google OAuth Android client; SHA-256 -> `ANDROID_SHA256_FINGERPRINTS`. Wrong SHA-1 = Google login fails only in the Play build.
6. Firebase (push): register Android app `io.canhgia.app`, put `google-services.json` in `android/app/`. The Gradle side is NOT wired yet (no `com.google.gms.google-services` plugin in `android/settings.gradle.kts` / `app/build.gradle.kts`; `main.dart` calls `Firebase.initializeApp()` without options), so add the plugin in the same change that adds the json (it fails the build when the json is missing, hence not committed). Then `FCM_ENABLED=true` in `env/prod.json`; FCM service account JSON -> Edge secret. Without this, push is silently off.

## 5. iOS (best effort, not a gate)
Needs macOS (GitHub `macos-latest` runner or borrowed Mac) and an Apple Developer account. No iOS workflow is committed because it cannot be verified without macOS. Known gaps (reviewer S7): set `GOOGLE_IOS_CLIENT_ID`, `GOOGLE_IOS_REVERSED_CLIENT_ID`, `APP_LINK_HOST` in `ios/Flutter/*.xcconfig`; add URL scheme = reversed client id; add Associated Domains `applinks:<host>`; APNs key uploaded to Firebase; fill `APPLE_TEAM_ID` + `IOS_BUNDLE_ID` for AASA. Then `flutter build ipa --dart-define-from-file=env/prod.json`, upload with App Store Connect API key, TestFlight internal. Public App Store release likely needs Sign in with Apple (guideline 4.8, verify) because Google login is offered.

## Rollback
Vercel instant rollback. Functions: redeploy previous commit (`git checkout <sha> && supabase functions deploy`). Migrations forward-fix only (never down-migrate money tables). Stop sync: `select cron.unschedule('<job>')` (re-run cron migration to restore). Unpublish CWS item; halt Play rollout. Rotate the AT token if it was ever logged.

## Go-live checklist
- [ ] AccessTrade: none of the 7 merchants is approved (only Lazada Malaysia + AccessTrade Referral, see `accesstrade-capability-matrix.md`). Apply per merchant; Shopee/TikTok/Agoda/Traveloka/Klook additionally need AT written OK that cashback is allowed. Until approved `create-link` returns `merchant_unavailable`/`link_rejected`.
- [ ] Real test purchase through a CanhGia link (confirm AT allows self-purchase first). After 24-72 h check `/v1/transactions` row has `utm_content=u<short>c<click>` (else `sub1`). Update matrix; if only `sub1` survives, the fallback covers it.
- [ ] `sync_state`/`sync_errors` healthy (see verify list above); 13 cron jobs.
- [ ] Non-admin cannot open `/admin`; admin has verified TOTP; >= 2 admins.
- [ ] VietQR from `/admin/withdrawals` scanned and matched in VCB and MB apps (amount, account, memo).
- [ ] `.well-known` fingerprints live; App Link opens `/r/<code>` in the Play build.
- [ ] Google + email OTP login on prod Android build; push received (FCM).
- [ ] Privacy policy URL reachable; store listings filled.
- [ ] Turnstile prod keys; Resend domain verified; auth rate limits raised.
- [ ] Staging probe: which header carries client IP on hosted Edge (`extension-login` uses first hop of `x-forwarded-for`).
- [ ] Run the security sweep from phase 11 against prod with test accounts (then delete them).

## Local e2e stack (what the suites assume)
Working dir = scratch copy (see `backend-contracts.md` "Local stack quirk"); ports 553xx.
- `config.toml`: `[auth.rate_limit] email_sent = 200` (default 2/hour blocks the OTP logins the web/extension suites need). Restart with `supabase stop && supabase start`.
- Edge functions: `supabase functions serve --no-verify-jwt --env-file <wd>/.env` from the scratch dir, `.env` = `ACCESSTRADE_TOKEN`, `ACCESSTRADE_BASE_URL=http://172.17.0.1:8787` (mock AT, reachable from the container), `CRON_SECRET`. `supabase start` alone loads only `supabase/functions/.env` (your real-AT values). After editing functions, re-copy them into the scratch dir.
- Keys: the CLI's local `ANON_KEY` / `SERVICE_ROLE_KEY` (`supabase status -o env`, public supabase-demo JWTs). Keys signed for another JWT secret give `UNAUTHORIZED_LEGACY_JWT` / `PGRST301`.
- Web: `apps/web/.env.local` needs `NEXT_PUBLIC_SUPABASE_URL=http://127.0.0.1:55321`, the publishable key and `NEXT_PUBLIC_TURNSTILE_SITE_KEY=1x00000000000000000000AA`; `pnpm build && pnpm start`.
- Mock AT: `deno run --allow-net --allow-read supabase/functions/tests/mock-accesstrade.ts`-style `startMock({port: 8787})` (the Deno integration tests start it themselves; stop any standalone copy first, the extension bar test needs one running).
- Seed users (`seed.sql`) carry `aud/role/email_confirmed_at/identities`; without them GoTrue answers `otp_disabled` (user not found) or 500 "Database error finding user".
- Run: `CRON_SECRET=<wd .env value> deno test --allow-net --allow-env --no-check supabase/tests/integration/*.test.ts`; `pnpm --filter web exec playwright test` (one aal2 login per run, TOTP secret cached in `apps/web/e2e/.auth`, git-ignored); extension: build with `WXT_SUPABASE_URL=http://127.0.0.1:55321 WXT_SUPABASE_PUBLISHABLE_KEY=<anon> WXT_LANDING_URL=http://localhost:3000 pnpm --filter extension build`, then `pnpm --filter extension e2e`.
- After `supabase db reset` delete `apps/web/e2e/.auth` (the admin TOTP factor is gone).
