begin;
create extension if not exists pgtap with schema extensions;
grant execute on all functions in schema extensions to public;
select plan(29);

insert into auth.users (id, email) values
  ('a0000000-0000-0000-0000-00000000000a', 'user@x.io'),
  ('b0000000-0000-0000-0000-00000000000b', 'admin1@x.io'),
  ('c0000000-0000-0000-0000-00000000000c', 'admin2@x.io');
insert into public.admins (user_id) values ('b0000000-0000-0000-0000-00000000000b'), ('c0000000-0000-0000-0000-00000000000c');
insert into public.kyc_profiles (user_id, full_name, full_name_norm, id_number_last4, id_number_hmac, front_path, back_path)
  values ('a0000000-0000-0000-0000-00000000000a', 'A', 'a', '1234', 'h', 'f', 'b');
insert into public.bank_accounts (id, user_id, bank_bin, account_number, account_name, account_name_norm)
  values ('e0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-00000000000a', '970436', '0123456789', 'A', 'a');
insert into public.wallet_ledger (user_id, entry_type, amount_vnd, idempotency_key)
  values ('a0000000-0000-0000-0000-00000000000a', 'manual_credit', 500000, 'seed');
-- two pending withdrawals (debited, as request_withdrawal would)
insert into public.withdrawals (id, request_key, user_id, amount, bank_account_id, bank_bin, account_number, account_name) values
  ('f0000000-0000-0000-0000-000000000001', gen_random_uuid(), 'a0000000-0000-0000-0000-00000000000a', 100000, 'e0000000-0000-0000-0000-000000000001', '970436', '0123456789', 'A'),
  ('f0000000-0000-0000-0000-000000000002', gen_random_uuid(), 'a0000000-0000-0000-0000-00000000000a', 50000, 'e0000000-0000-0000-0000-000000000001', '970436', '0123456789', 'A');
insert into public.wallet_ledger (user_id, entry_type, amount_vnd, withdrawal_id, idempotency_key) values
  ('a0000000-0000-0000-0000-00000000000a', 'withdrawal_debit', -100000, 'f0000000-0000-0000-0000-000000000001', 'wd:1'),
  ('a0000000-0000-0000-0000-00000000000a', 'withdrawal_debit', -50000, 'f0000000-0000-0000-0000-000000000002', 'wd:2');

select set_config('t.user', '{"sub":"a0000000-0000-0000-0000-00000000000a","role":"authenticated","aal":"aal2"}', true);
select set_config('t.ad1_aal1', '{"sub":"b0000000-0000-0000-0000-00000000000b","role":"authenticated","aal":"aal1"}', true);
select set_config('t.ad1', '{"sub":"b0000000-0000-0000-0000-00000000000b","role":"authenticated","aal":"aal2"}', true);
select set_config('t.ad2', '{"sub":"c0000000-0000-0000-0000-00000000000c","role":"authenticated","aal":"aal2"}', true);

set local role authenticated;
select set_config('request.jwt.claims', current_setting('t.user'), true);
select is(public.is_admin(), false, 'non-admin (even aal2) is not admin');
select throws_ok($$select * from public.admin_claim_withdrawal('f0000000-0000-0000-0000-000000000001')$$, 'P0001', 'forbidden', 'claim: forbidden');
select throws_ok($$select * from public.admin_mark_paid('{}', 'ref')$$, 'P0001', 'forbidden', 'mark_paid: forbidden');
select throws_ok($$select * from public.admin_reject_withdrawals('{}', 'r')$$, 'P0001', 'forbidden', 'reject: forbidden');
select throws_ok($$select public.admin_verify_bank_account('e0000000-0000-0000-0000-000000000001')$$, 'P0001', 'forbidden', 'verify bank: forbidden');
select throws_ok($$select public.admin_review_kyc('a0000000-0000-0000-0000-00000000000a', 'verified', null)$$, 'P0001', 'forbidden', 'review kyc: forbidden');
select throws_ok($$select public.admin_adjust_wallet('a0000000-0000-0000-0000-00000000000a', 1, 'x')$$, 'P0001', 'forbidden', 'adjust: forbidden');
select set_config('request.jwt.claims', current_setting('t.ad1_aal1'), true);
select is(public.is_admin(), false, 'Sec-6: admin without aal2 is not admin');
select throws_ok($$select * from public.admin_claim_withdrawal('f0000000-0000-0000-0000-000000000001')$$, 'P0001', 'forbidden', 'aal1 admin: forbidden');

-- claim / not_claimer / bank_unverified / paid
select set_config('request.jwt.claims', current_setting('t.ad1'), true);
select is(public.is_admin(), true, 'admin at aal2');
select results_eq($$select status::text, claimed_by from public.admin_claim_withdrawal('f0000000-0000-0000-0000-000000000001')$$,
  $$values ('processing', 'b0000000-0000-0000-0000-00000000000b'::uuid)$$, 'claim -> processing');
select throws_ok($$select * from public.admin_claim_withdrawal('f0000000-0000-0000-0000-000000000001')$$, 'P0001', 'invalid_state', 'already claimed within 30 min');
select set_config('request.jwt.claims', current_setting('t.ad2'), true);
select results_eq($$select ok, error from public.admin_mark_paid(array['f0000000-0000-0000-0000-000000000001']::uuid[], 'FT1')$$,
  $$values (false, 'not_claimer')$$, 'second admin mark_paid -> not_claimer');
select set_config('request.jwt.claims', current_setting('t.ad1'), true);
select results_eq($$select ok, error from public.admin_mark_paid(array['f0000000-0000-0000-0000-000000000001']::uuid[], 'FT1')$$,
  $$values (false, 'bank_unverified')$$, 'unverified bank -> bank_unverified');
select lives_ok($$select public.admin_verify_bank_account('e0000000-0000-0000-0000-000000000001')$$, 'verify bank');
select throws_ok($$select public.admin_verify_bank_account('e0000000-0000-0000-0000-000000000001')$$, 'P0001', 'invalid_state', 'verify bank twice -> invalid_state');
select results_eq($$select ok, error from public.admin_mark_paid(array['f0000000-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000002']::uuid[], 'FT1')$$,
  $$values (true, null), (false, 'invalid_state')$$, 'batch: claimed row paid, unclaimed row invalid_state');
select throws_ok($$select * from public.admin_mark_paid(array['f0000000-0000-0000-0000-000000000001']::uuid[], ' ')$$, 'P0001', 'invalid_input', 'blank transfer_ref');

-- reject refunds once
select results_eq($$select ok, error from public.admin_reject_withdrawals(array['f0000000-0000-0000-0000-000000000002']::uuid[], 'sai thong tin')$$,
  $$values (true, null)$$, 'reject pending withdrawal');
select results_eq($$select ok, error from public.admin_reject_withdrawals(array['f0000000-0000-0000-0000-000000000002']::uuid[], 'again')$$,
  $$values (false, 'invalid_state')$$, 'reject twice -> invalid_state, no second refund');

-- kyc review + wallet adjust
select throws_ok($$select public.admin_review_kyc('a0000000-0000-0000-0000-00000000000a', 'maybe', null)$$, 'P0001', 'invalid_input', 'bad decision');
select lives_ok($$select public.admin_review_kyc('a0000000-0000-0000-0000-00000000000a', 'verified', null)$$, 'review kyc');
select throws_ok($$select public.admin_review_kyc('a0000000-0000-0000-0000-00000000000a', 'rejected', 'x')$$, 'P0001', 'invalid_state', 'kyc already reviewed');
select throws_ok($$select public.admin_adjust_wallet('a0000000-0000-0000-0000-00000000000a', 0, 'x')$$, 'P0001', 'invalid_input', 'zero adjustment');
select lives_ok($$select public.admin_adjust_wallet('a0000000-0000-0000-0000-00000000000a', -1000000, 'clawback')$$, 'adjustment may overdraw');
reset role;

select is((select available_vnd from public.wallets where user_id = 'a0000000-0000-0000-0000-00000000000a'), (500000 - 100000 - 50000 + 50000 - 1000000)::bigint,
  'wallet: debit 100k stays, rejected 50k refunded, -1M adjustment');
select ok((select count(*) >= 8 from public.admin_audit_log), 'every admin call audited');
select results_eq($$select status::text, transfer_ref from public.withdrawals where id = 'f0000000-0000-0000-0000-000000000001'$$, $$values ('paid', 'FT1')$$, 'paid withdrawal recorded');
select is_empty($$select * from public.check_wallet_drift()$$, 'no wallet drift');
select * from finish();
rollback;
