begin;
create extension if not exists pgtap with schema extensions;
grant execute on all functions in schema extensions to public;
select plan(29);

insert into public.merchants (id, name) values ('shopee', 'Shopee');
insert into auth.users (id, email) values
  ('a0000000-0000-0000-0000-00000000000a', 'a@x.io'), ('b0000000-0000-0000-0000-00000000000b', 'b@x.io');
insert into public.wallet_ledger (user_id, entry_type, amount_vnd, idempotency_key) values
  ('a0000000-0000-0000-0000-00000000000a', 'manual_credit', 100, 'la'), ('b0000000-0000-0000-0000-00000000000b', 'manual_credit', 200, 'lb');
insert into public.orders (id, source, merchant_id, transaction_id, user_id) values
  ('c0000000-0000-0000-0000-000000000001', 'manual', 'shopee', 'A1', 'a0000000-0000-0000-0000-00000000000a'),
  ('c0000000-0000-0000-0000-000000000002', 'manual', 'shopee', 'B1', 'b0000000-0000-0000-0000-00000000000b');
insert into public.order_raw (order_id, raw) values ('c0000000-0000-0000-0000-000000000001', '{"secret":1}');
insert into public.user_risk (user_id, risk_score) values ('a0000000-0000-0000-0000-00000000000a', 90);
insert into public.fraud_flags (user_id, type, dedupe_key) values ('a0000000-0000-0000-0000-00000000000a', 'abnormal_clicks', 'f1');
insert into public.notifications (user_id, type, title) values
  ('a0000000-0000-0000-0000-00000000000a', 'system', 'na'), ('b0000000-0000-0000-0000-00000000000b', 'system', 'nb');
insert into public.bank_accounts (user_id, bank_bin, account_number, account_name, account_name_norm) values
  ('b0000000-0000-0000-0000-00000000000b', '970436', '111111', 'B', 'b');
insert into public.push_tokens (token, user_id, platform) values ('tb', 'b0000000-0000-0000-0000-00000000000b', 'android');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-0000-0000-00000000000a","role":"authenticated","aal":"aal1"}', true);

select is((select count(*)::int from public.profiles), 1, 'profiles: own row only');
select is((select count(*)::int from public.wallets), 1, 'wallets: own row only');
select is((select count(*)::int from public.wallet_ledger), 1, 'ledger: own rows only');
select is((select count(*)::int from public.orders), 1, 'orders: own rows only');
select is((select count(*)::int from public.notifications), 1, 'notifications: own rows only');
select is((select count(*)::int from public.bank_accounts), 0, 'bank accounts of others invisible');
select is((select count(*)::int from public.user_risk), 0, 'Sec-9: risk score never visible to the user');
select is((select count(*)::int from public.order_raw), 0, 'Sec-9: raw AT payload never visible to the user');
select is((select count(*)::int from public.fraud_flags), 0, 'fraud flags admin-only');
select is((select count(*)::int from public.app_settings), 0, 'app_settings admin-only');
select is((select count(*)::int from public.admin_audit_log), 0, 'audit log admin-only');
select is((select count(*)::int from public.sync_errors), 0, 'sync_errors admin-only');
select is((select count(*)::int from public.extension_login_codes), 0, 'extension codes hidden');

-- no direct writes on money tables
select throws_ok($$update public.wallets set available_vnd = 1000000000$$, '42501', null, 'wallets: no UPDATE');
select throws_ok($$insert into public.wallet_ledger (user_id, entry_type, amount_vnd, idempotency_key) values ('a0000000-0000-0000-0000-00000000000a', 'manual_credit', 5, 'x')$$, '42501', null, 'ledger: no INSERT');
select throws_ok($$update public.profiles set locked_at = null, withdrawal_hold_until = null$$, '42501', null, 'profiles: no UPDATE (holds cannot be cleared)');
select throws_ok($$insert into public.withdrawals (request_key, user_id, amount, bank_bin, account_number, account_name) values (gen_random_uuid(), 'a0000000-0000-0000-0000-00000000000a', 1, 'x', 'x', 'x')$$, '42501', null, 'withdrawals: no INSERT');
select throws_ok($$select * from private.user_pins$$, '42501', null, 'private schema closed');
select throws_ok($$insert into public.push_tokens (token, user_id, platform) values ('tx', 'b0000000-0000-0000-0000-00000000000b', 'ios')$$, '42501', null, 'push_tokens: cannot insert for another user');
select lives_ok($$insert into public.push_tokens (token, user_id, platform) values ('ta', 'a0000000-0000-0000-0000-00000000000a', 'ios')$$, 'push_tokens: own insert');
delete from public.push_tokens where token = 'tb';
reset role;
select is((select count(*)::int from public.push_tokens where token = 'tb'), 1, 'push_tokens: cannot delete another user''s token');

-- anon: reference data only
set local role anon;
select is((select count(*)::int from public.merchants), 1, 'anon reads merchants');
select throws_ok($$select * from public.profiles$$, '42501', null, 'anon cannot read profiles');
select throws_ok($$select * from public.wallets$$, '42501', null, 'anon cannot read wallets');
reset role;

-- admin (aal2) sees everything, aal1 admin does not
insert into public.admins (user_id) values ('b0000000-0000-0000-0000-00000000000b');
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"b0000000-0000-0000-0000-00000000000b","role":"authenticated","aal":"aal1"}', true);
select is((select count(*)::int from public.wallets), 1, 'admin without aal2 sees own row only');
select set_config('request.jwt.claims', '{"sub":"b0000000-0000-0000-0000-00000000000b","role":"authenticated","aal":"aal2"}', true);
select is((select count(*)::int from public.wallets), 2, 'admin at aal2 sees all wallets');
select is((select count(*)::int from public.user_risk), 1, 'admin at aal2 reads user_risk');
reset role;

-- realtime + storage
select is((select array_agg(tablename::text order by tablename) from pg_publication_tables
            where pubname = 'supabase_realtime' and schemaname = 'public'),
  array['notifications', 'orders', 'wallets', 'withdrawals'], 'realtime publication tables');
select results_eq($$select id, public, file_size_limit from storage.buckets where id in ('kyc', 'complaints') order by id$$,
  $$values ('complaints', false, 5242880::bigint), ('kyc', false, 5242880::bigint)$$, 'private 5MB buckets');

select * from finish();
rollback;
