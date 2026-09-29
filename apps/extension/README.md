# CanhGia Chrome extension (WXT, MV3)

`pnpm --filter extension lint | typecheck | test | build` (build output: `.output/chrome-mv3`, load unpacked in Chrome).
A production build (`wxt build`/`zip`) fails unless `WXT_SUPABASE_URL`, `WXT_SUPABASE_PUBLISHABLE_KEY` and `WXT_LANDING_URL` are set; dev values in `.env.example` are local only.

## Fixed extension id (needed for Google login)
Google sign-in redirects to `https://<extension-id>.chromiumapp.org/`, so the id must be stable and allowlisted.
1. `openssl genrsa -out key.pem 2048` (keep private, never commit)
2. `WXT_EXTENSION_KEY=$(openssl rsa -in key.pem -pubout -outform DER | base64 -w0)` in `.env` (see `.env.example`); this is written to manifest `key`.
3. Id = first 32 hex chars of sha256(DER public key) mapped 0-f to a-p; easiest: load the build once and read it on `chrome://extensions`.
4. Replace `EXTENSION_ID` in `supabase/config.toml` `additional_redirect_urls` (and the prod Auth redirect URLs) with `https://<id>.chromiumapp.org/`.

QR-pair login needs no redirect; it uses the `extension-login` Edge Function.

## Scope
Bar / labels / checkout toast inject only on shopee.vn, lazada.vn, tiki.vn, tiktok.com (page shapes in `src/lib/merchant-page-detectors.ts`). Agoda, Traveloka, Klook: popup activation only.
