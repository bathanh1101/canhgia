# Development roadmap

Snapshot 2026-09-30. Status is from git + reports, not from `plan.md` (its table was never updated).

## Phases
| # | Phase | Status | Evidence / gap |
|---|---|---|---|
| 01 | Foundation, AT spike | done (spike partial) | `a2de1d1`, `787ca71`; POST link creation + utm round trip + transactions not run (no approved campaign) |
| 02a | DB core + money | done | pgTAP; reviewed, fixes `1e4dbb0` |
| 02b | DB engagement/admin/reference | done | `3204320`; gaps below |
| 03 | Edge + cron | done, unverified live | tested against mock AT only; never run on hosted Supabase |
| 04 | Flutter core | done | Android target; iOS incomplete |
| 05 | Flutter shopping | done | `0904d83` |
| 06 | Flutter wallet/rewards | done | `93dcc0f`; reset PIN missing |
| 07 | Web shell + admin auth | done | `98f3ff0` |
| 08 | Admin A | done | `f79c09b` |
| 09 | Admin B | done | `173e48d` |
| 10 | Extension | done, partial verification | reviewed; e2e blocked on browser runtime |
| 11 | Integration + e2e | partial | harness exists; last run failing/blocked (see changelog); mobile integration_test not run |
| 12 | Docs + deploy | partial (prepared) | docs, workflows, privacy page, Android signing done; all cloud steps blocked on accounts |

## Human prerequisites still open (blocks phase 12 execution)
- AccessTrade: approvals for all 7 merchants (none approved), token for prod, ~200.000 d for a real test purchase, AT answer on cashback + self-purchase.
- Supabase cloud project (Pro), Vercel project, domain (canhgia.vn, not owned), Resend + DNS.
- Google OAuth clients (Web, Android, iOS), Firebase project (+ APNs later), Cloudflare Turnstile prod site.
- Play Console, Chrome Web Store dev account, Apple Developer + macOS runner.
- Extension key pair (stable id), Android upload keystore.
- Wiring left in repo: Firebase Gradle plugin + `google-services.json` (Android), iOS xcconfig/URL scheme/entitlements, `EXTENSION_ID` in `config.toml`, `apps/web/.env.example` shows wrong `vn.canhgia.canhgia` ids (real `io.canhgia.app`).

## Backend gaps found (need a new migration each; owner: next DB phase)
1. `reset_withdraw_pin` RPC: `set_withdraw_pin` on an existing PIN needs a `verify_pin` token, so a user who forgot the PIN cannot withdraw (fresh OTP + long withdrawal hold + audit).
2. `gmv_12m` RPC: no RPC exposes the user's credited 12-month GMV (`refresh_vip_tiers` computes it internally only); the rewards screen's `tierProgress` needs it as input.
3. Held-referral admin RPC: referrals in status `held` have no admin action to release/void.
4. Campaign commission override RPC: `campaign_commissions` (seeded, sample bps from T&C text) has no admin RPC; only `admin_upsert_cashback_rule`. Also `commission_policies` 404s on AT so sync cannot refresh rates.
5. `evaluate_price_alerts` semantics decision: runs only after `sync-datafeeds` (delta window 19-22 UTC = 02-05 ICT, i.e. about once a day); alerts at most once per 24 h per item and only for datafeed merchants (Shopee, Tiki). Decide: own cron (e.g. hourly) vs keep, and whether target compares against min offer price across the whole group.
6. Account deletion / data export path (Decree 13 promised in the privacy policy by request): `kyc_profiles`/`bank_accounts`/`wallets` use `on delete restrict`; no runbook or RPC.
7. Admin re-claim of `processing` withdrawal after 30 min (double payout risk); audit of `forbidden` attempts.

## Deferred (not in MVP)
Deferred referral deep link after store install, phone OTP, Facebook/Apple login (Sign in with Apple required before public iOS release), automated payout (payOS after company registration), bank-name lookup, eKYC vendor, coin redemption, promo broadcast, fuzzy product grouping, geo-IP on extension approval, iOS TestFlight, i18n.

## Next steps (order)
1. Obtain AT approvals + test purchase (longest lead time).
2. Create Supabase project, follow `deployment-guide.md` section 1, run e2e green against local stack meanwhile.
3. Vercel + Android internal track + CWS unlisted; go-live checklist.
4. Backend gaps 1, 3, 4 before real payouts; 5 and 6 before public launch.
