# Code standards (1 page)

- **Files**: Dart `snake_case.dart`, TS/JS `kebab-case.ts`, SQL migrations `YYYYMMDDHHMMSS_name.sql`. Under 200 lines per code file; split by responsibility.
- **Money**: `bigint` VND (no decimals) and rates in basis points (bps). Never floats.
- **Money logic lives in SQL** (functions/RPC, one transaction, row locks). Clients and Edge Functions call it; they never compute balances.
- **Errors**: one error vocabulary defined in phase 02a; apps map codes to Vietnamese messages. Do not invent new codes client-side.
- **Secrets**: no service key or AccessTrade token in any client (mobile, web browser bundle, extension). Server only (Edge Functions / Next server). `.env*`, keystores, `key.properties` are gitignored; commit `.env.example` only.
- **Base URLs**: read `WEB_BASE_URL` / `APP_BASE_URL` from env; never hardcode a domain.
- **Boundaries**: validate all external input (request bodies, AccessTrade responses, deep links) where it enters.
- **Async**: every async call handles its error; no swallowed exceptions.
- **UI**: Vietnamese strings hardcoded (no i18n); colors from `docs/design-tokens.md` only.
- **Tests**: new logic ships with happy-path and key failure-path tests; pgTAP for SQL, `deno test` for functions.
- **Commits**: conventional (`feat:`, `fix:`, `chore:`...).
