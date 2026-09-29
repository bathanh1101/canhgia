begin;
create extension if not exists pgtap with schema extensions;
grant execute on all functions in schema extensions to public;
select plan(33);

insert into public.merchants (id, name) values ('shopee', 'Shopee');
insert into auth.users (id, email) values
  ('a0000000-0000-0000-0000-00000000000a', 'a@x.io'), ('b0000000-0000-0000-0000-00000000000b', 'b@x.io');
-- A: verified KYC, bank, 1.000.000 available. B: nothing.
insert into public.kyc_profiles (user_id, full_name, full_name_norm, id_number_last4, id_number_hmac, front_path, back_path, status)
  values ('a0000000-0000-0000-0000-00000000000a', 'Nguyen Van A', 'nguyen van a', '1234', 'h', 'f', 'b', 'verified');
insert into public.bank_accounts (id, user_id, bank_bin, account_number, account_name, account_name_norm)
  values ('e0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-00000000000a', '970436', '0123456789', 'NGUYEN VAN A', 'nguyen van a');
insert into public.wallet_ledger (user_id, entry_type, amount_vnd, idempotency_key)
  values ('a0000000-0000-0000-0000-00000000000a', 'manual_credit', 1000000, 'seed');

-- claims: A with fresh email OTP (amr) vs plain session
select set_config('t.a_otp', jsonb_build_object('sub', 'a0000000-0000-0000-0000-00000000000a', 'role', 'authenticated', 'aal', 'aal1',
  'amr', jsonb_build_array(jsonb_build_object('method', 'otp', 'timestamp', extract(epoch from now())::bigint)))::text, true);
select set_config('t.a_old', jsonb_build_object('sub', 'a0000000-0000-0000-0000-00000000000a', 'role', 'authenticated', 'aal', 'aal1',
  'amr', jsonb_build_array(jsonb_build_object('method', 'otp', 'timestamp', extract(epoch from now())::bigint - 3600)))::text, true);
select set_config('t.a', '{"sub":"a0000000-0000-0000-0000-00000000000a","role":"authenticated","aal":"aal1"}', true);
select set_config('t.b', '{"sub":"b0000000-0000-0000-0000-00000000000b","role":"authenticated","aal":"aal1"}', true);

-- set_withdraw_pin ---------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims', current_setting('t.a_old'), true);
select throws_ok($$select public.set_withdraw_pin('123456')$$, 'P0001', 'pin_invalid', 'first PIN needs a fresh OTP (stale otp rejected)');
select set_config('request.jwt.claims', current_setting('t.a_otp'), true);
select throws_ok($$select public.set_withdraw_pin('12ab')$$, 'P0001', 'invalid_input', 'malformed PIN rejected');
select lives_ok($$select public.set_withdraw_pin('123456')$$, 'first PIN with fresh OTP');
select set_config('request.jwt.claims', current_setting('t.a'), true);
select throws_ok($$select public.set_withdraw_pin('654321')$$, 'P0001', 'pin_invalid', 'changing PIN needs a pin_token');
reset role;
select ok((select has_pin from public.profiles where id = 'a0000000-0000-0000-0000-00000000000a'), 'has_pin set');
select ok((select withdrawal_hold_until is null from public.profiles where id = 'a0000000-0000-0000-0000-00000000000a'), 'first PIN sets no hold');
select ok((select pin_hash <> '123456' and pin_hash like '$2%' from private.user_pins where user_id = 'a0000000-0000-0000-0000-00000000000a'), 'PIN stored as bcrypt');

-- verify_pin lockout: wrong PIN commits the counter (returns, never raises)
set local role authenticated;
select set_config('request.jwt.claims', current_setting('t.a'), true);
select results_eq($$select ok, attempts_left from public.verify_pin('000000')$$, $$values (false, 4)$$, 'wrong PIN: 4 left');
select results_eq($$select ok, attempts_left from public.verify_pin('000000')$$, $$values (false, 3)$$, 'wrong PIN: 3 left');
reset role;
select is((select failed_attempts from private.user_pins where user_id = 'a0000000-0000-0000-0000-00000000000a'), 2, 'counter persisted');
set local role authenticated;
select set_config('request.jwt.claims', current_setting('t.a'), true);
select verify_pin.ok from public.verify_pin('000000');
select verify_pin.ok from public.verify_pin('000000');
select results_eq($$select ok, attempts_left, locked_until is not null from public.verify_pin('000000')$$, $$values (false, 0, true)$$, '5th wrong PIN locks');
select throws_ok($$select * from public.verify_pin('123456')$$, 'P0001', 'pin_locked', 'locked even with the right PIN');
reset role;
update private.user_pins set locked_until = null, failed_attempts = 0;

-- happy path: token -> change PIN (24h hold) 
set local role authenticated;
select set_config('request.jwt.claims', current_setting('t.a'), true);
select set_config('t.tok', (select pin_token::text from public.verify_pin('123456')), true);
select lives_ok($$select public.set_withdraw_pin('654321', current_setting('t.tok')::uuid)$$, 'change PIN with token');
reset role;
select ok((select withdrawal_hold_until > now() + interval '23 hours' from public.profiles where id = 'a0000000-0000-0000-0000-00000000000a'), 'PIN change -> 24h hold');
select ok((select count(*) = 1 from private.pin_tokens where used_at is not null), 'token marked used');

-- request_withdrawal error paths. A failing statement rolls back its own token use, so one token serves them all.
set local role authenticated;
select set_config('request.jwt.claims', current_setting('t.a'), true);
select set_config('t.tok', (select pin_token::text from public.verify_pin('654321')), true);
select throws_ok($$select * from public.request_withdrawal('f0000000-0000-0000-0000-000000000001', 100000, 'e0000000-0000-0000-0000-000000000001', current_setting('t.tok')::uuid)$$,
  'P0001', 'hold_active', 'withdraw during hold -> hold_active');
reset role;
update public.profiles set withdrawal_hold_until = null where id = 'a0000000-0000-0000-0000-00000000000a';
update public.app_settings set value = '500000' where key = 'withdraw_daily_cap_vnd';
set local role authenticated;
select set_config('request.jwt.claims', current_setting('t.a'), true);
select throws_ok($$select * from public.request_withdrawal('f0000000-0000-0000-0000-000000000001', 600000, 'e0000000-0000-0000-0000-000000000001', current_setting('t.tok')::uuid)$$,
  'P0001', 'daily_cap', 'over daily cap');
select throws_ok($$select * from public.request_withdrawal('f0000000-0000-0000-0000-000000000001', 10000, 'e0000000-0000-0000-0000-000000000001', current_setting('t.tok')::uuid)$$,
  'P0001', 'invalid_input', 'below min_withdraw_vnd');
select throws_ok($$select * from public.request_withdrawal('f0000000-0000-0000-0000-000000000001', 100000, gen_random_uuid(), current_setting('t.tok')::uuid)$$,
  'P0001', 'invalid_input', 'unknown bank account');
select throws_ok($$select * from public.request_withdrawal('f0000000-0000-0000-0000-000000000001', 100000, 'e0000000-0000-0000-0000-000000000001', gen_random_uuid())$$,
  'P0001', 'pin_invalid', 'unknown pin_token');
select lives_ok($$select * from public.request_withdrawal('f0000000-0000-0000-0000-000000000001', 400000, 'e0000000-0000-0000-0000-000000000001', current_setting('t.tok')::uuid)$$,
  'withdrawal accepted');
select throws_ok($$select * from public.request_withdrawal('f0000000-0000-0000-0000-000000000002', 100000, 'e0000000-0000-0000-0000-000000000001', current_setting('t.tok')::uuid)$$,
  'P0001', 'pin_invalid', 'used pin_token rejected');
select set_config('t.tok', (select pin_token::text from public.verify_pin('654321')), true);
select throws_ok($$select * from public.request_withdrawal('f0000000-0000-0000-0000-000000000002', 200000, 'e0000000-0000-0000-0000-000000000001', current_setting('t.tok')::uuid)$$,
  'P0001', 'daily_cap', '24h cap counts earlier withdrawals');
select results_eq($$select withdrawal_id::text, status::text from public.request_withdrawal('f0000000-0000-0000-0000-000000000001', 400000, 'e0000000-0000-0000-0000-000000000001', current_setting('t.tok')::uuid)$$,
  $$select id::text, 'pending' from public.withdrawals where request_key = 'f0000000-0000-0000-0000-000000000001'$$, 'same request_key replays the same withdrawal');
reset role;
select is((select available_vnd from public.wallets where user_id = 'a0000000-0000-0000-0000-00000000000a'), 600000::bigint, 'debited exactly once');
select is((select count(*)::int from public.withdrawals), 1, 'one withdrawal row');

-- expired token, insufficient balance
update public.app_settings set value = '5000000' where key = 'withdraw_daily_cap_vnd';
set local role authenticated;
select set_config('request.jwt.claims', current_setting('t.a'), true);
select set_config('t.tok', (select pin_token::text from public.verify_pin('654321')), true);
reset role;
update private.pin_tokens set expires_at = now() - interval '1 second' where token = current_setting('t.tok')::uuid;
set local role authenticated;
select set_config('request.jwt.claims', current_setting('t.a'), true);
select throws_ok($$select * from public.request_withdrawal('f0000000-0000-0000-0000-000000000003', 100000, 'e0000000-0000-0000-0000-000000000001', current_setting('t.tok')::uuid)$$,
  'P0001', 'pin_invalid', 'expired pin_token rejected');
select set_config('t.tok', (select pin_token::text from public.verify_pin('654321')), true);
select throws_ok($$select * from public.request_withdrawal('f0000000-0000-0000-0000-000000000003', 700000, 'e0000000-0000-0000-0000-000000000001', current_setting('t.tok')::uuid)$$,
  'P0001', 'insufficient_balance', 'amount above available');
reset role;
select is((select count(*)::int from public.withdrawals), 1, 'failed attempts create no withdrawal');

-- gates: kyc_required (B), account_locked
insert into public.wallet_ledger (user_id, entry_type, amount_vnd, idempotency_key)
  values ('b0000000-0000-0000-0000-00000000000b', 'manual_credit', 100000, 'seedb');
set local role authenticated;
select set_config('request.jwt.claims', current_setting('t.b'), true);
select throws_ok($$select * from public.request_withdrawal(gen_random_uuid(), 100000, gen_random_uuid(), gen_random_uuid())$$,
  'P0001', 'kyc_required', 'no KYC -> kyc_required');
select throws_ok($$select * from public.verify_pin('123456')$$, 'P0001', 'pin_invalid', 'verify_pin without a PIN set');
reset role;
update public.profiles set locked_at = now() where id = 'b0000000-0000-0000-0000-00000000000b';
set local role authenticated;
select set_config('request.jwt.claims', current_setting('t.b'), true);
select throws_ok($$select * from public.request_withdrawal(gen_random_uuid(), 100000, gen_random_uuid(), gen_random_uuid())$$,
  'P0001', 'account_locked', 'locked account');
reset role;

select is_empty($$select * from public.check_wallet_drift()$$, 'no wallet drift');
select * from finish();
rollback;
