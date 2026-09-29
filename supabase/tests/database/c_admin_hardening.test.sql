begin;
create extension if not exists pgtap with schema extensions;
grant execute on all functions in schema extensions to public;
select plan(11);

insert into auth.users (id, email) values
  ('a0000000-0000-0000-0000-00000000000a', 'user@x.io'),
  ('b0000000-0000-0000-0000-00000000000b', 'admin1@x.io');
insert into public.admins (user_id) values ('b0000000-0000-0000-0000-00000000000b');
select set_config('t.user', '{"sub":"a0000000-0000-0000-0000-00000000000a","role":"authenticated","aal":"aal1"}', true);
select set_config('t.ad_aal1', '{"sub":"b0000000-0000-0000-0000-00000000000b","role":"authenticated","aal":"aal1"}', true);
select set_config('t.ad', '{"sub":"b0000000-0000-0000-0000-00000000000b","role":"authenticated","aal":"aal2"}', true);

set local role authenticated;
select set_config('request.jwt.claims', current_setting('t.user'), true);
select is(public.is_admin_candidate(), false, 'non-admin is not a candidate');
select throws_ok($$select public.admin_log_action('export_orders', '{}')$$, 'P0001', 'forbidden', 'log_action: forbidden for non-admin');
select set_config('request.jwt.claims', current_setting('t.ad_aal1'), true);
select is(public.is_admin_candidate(), true, 'admin row at aal1 is a candidate');
select throws_ok($$select public.admin_log_action('export_orders', '{}')$$, 'P0001', 'forbidden', 'log_action: aal1 forbidden');
select set_config('request.jwt.claims', current_setting('t.ad'), true);
select lives_ok($$select public.admin_log_action('export_orders', '{"q":"x"}')$$, 'log_action: admin ok');
select throws_ok($$select public.admin_log_action('drop_everything', '{}')$$, 'P0001', 'invalid_input', 'log_action: action allow-list');

reset role;
insert into public.wallet_ledger (user_id, entry_type, amount_vnd, idempotency_key)
  values ('a0000000-0000-0000-0000-00000000000a', 'manual_credit', 1000, 'seed');
set local role authenticated;
select set_config('request.jwt.claims', current_setting('t.ad'), true);
select is(
  (select public.admin_adjust_wallet('a0000000-0000-0000-0000-00000000000a', 500, 'fix', null, '11111111-1111-4111-8111-111111111111')),
  (select public.admin_adjust_wallet('a0000000-0000-0000-0000-00000000000a', 500, 'fix', null, '11111111-1111-4111-8111-111111111111')),
  'same request id returns the same ledger row');
reset role;
select is((select count(*)::int from public.wallet_ledger where idempotency_key = 'adm:11111111-1111-4111-8111-111111111111'), 1, 'credited once');
select is((select available_vnd::int from public.wallets where user_id = 'a0000000-0000-0000-0000-00000000000a'), 1500, 'balance moved once');

insert into public.withdrawals (id, request_key, user_id, amount, bank_bin, account_number, account_name, transfer_ref, status) values
  ('f0000000-0000-0000-0000-000000000001', gen_random_uuid(), 'a0000000-0000-0000-0000-00000000000a', 1, '970436', '1', 'A', 'FT1', 'paid');
select throws_ok($$insert into public.withdrawals (request_key, user_id, amount, bank_bin, account_number, account_name, transfer_ref, status)
  values (gen_random_uuid(), 'a0000000-0000-0000-0000-00000000000a', 1, '970436', '1', 'A', 'FT1', 'paid')$$, '23505', null, 'transfer_ref unique');
select is((select count(*)::int from public.admin_audit_log where action = 'export_orders'), 1, 'export audited');

select * from finish();
rollback;
