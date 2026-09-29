# CanhGia

Cashback app: Flutter mobile, Next.js web/admin, WXT Chrome extension, Supabase backend, AccessTrade affiliate API. Vietnamese only.

## Layout
`apps/web`, `apps/extension` (pnpm workspace; scaffolded in phases 07 / 10), `apps/mobile` (Flutter, phase 04), `supabase/`, `docs/`. Plan: `plans/260929-2005-canhgia-full-build/`.

## Toolchain
Pinned: Node 24 (`.nvmrc`), pnpm 11.25.0. Verified here (WSL2): node 24.16.0, pnpm 11.25.0, supabase CLI 2.116.0, docker running, git 2.43, gh 2.45.

Expected locations of user-space installs (no sudo), add to shell profile:
```
export PATH=$HOME/.deno/bin:$HOME/flutter/bin:$HOME/jdk/bin:$PATH
export ANDROID_HOME=$HOME/android-sdk JAVA_HOME=$HOME/jdk
```
Flutter/Android/adb steps (device over wireless adb, `flutter doctor`) are deferred to phase 04; iOS needs a macOS runner (phase 12).

## Quick start
```
pnpm install
export TURNSTILE_SECRET=1x0000000000000000000000000000000AA   # Cloudflare always-pass TEST secret (or put in supabase/.env)
export SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_ID=local SUPABASE_AUTH_EXTERNAL_GOOGLE_SECRET=local   # placeholders until real OAuth clients exist
supabase start -x studio,imgproxy    # API :54321, DB :54322, Mailpit :54324 (Studio excluded)
supabase stop
```
Turnstile local site key (test, always pass): `1x00000000000000000000AA`. Never commit real keys; `.env*` is gitignored (commit `.env.example` only).
Base URLs come from env `WEB_BASE_URL` / `APP_BASE_URL` (no domain yet; Vercel `*.vercel.app` for now).
`supabase/config.toml` redirect list contains the placeholder `EXTENSION_ID` until the extension id is known.

## Human prerequisites checklist
- [ ] AccessTrade token + dashboard access, ~200.000đ for one real test purchase - blocks 01 spike, then 02a (link/T&C/matrix) and 03 (utm_content round-trip)
- [ ] Google Cloud OAuth clients: Web, Android (debug SHA-1), iOS - blocks 04, 07
- [ ] Firebase project (dev + prod), APNs key later - blocks 04, 12
- [ ] Cloudflare Turnstile site (real site key + secret) - blocks 04, 07 (test keys work locally)
- [ ] Resend account (onboarding sender until DNS), canhgia.vn domain + SPF/DKIM - blocks 07, 12
- [ ] Remote Supabase project `canhgia-staging` - blocks 03 deploy, device testing
- [ ] Java 17 + Android SDK + Flutter + Deno (lead installing to paths above), Android phone with wireless debugging - blocks 04
- [ ] Apple Developer + macOS runner, Play Console, Chrome Web Store dev account ($5) - blocks 12

A missing item at its phase start means that phase is BLOCKED, not improvised.

## Docs
`docs/system-architecture.md`, `docs/deployment-guide.md` (deploy order, env matrix, go-live checklist), `docs/project-changelog.md`, `docs/development-roadmap.md`, `docs/code-standards.md`, `docs/design-tokens.md`, `docs/backend-contracts.md`, `docs/web-admin-conventions.md`, `docs/mobile-conventions.md`, `docs/accesstrade-capability-matrix.md`, `docs/accesstrade-samples/`.

## Deploy
Manual workflows in `.github/workflows/deploy-{supabase,web,extension,android}.yml` (`workflow_dispatch`; skip with a warning when secrets are missing). Steps and secrets: `docs/deployment-guide.md`.
