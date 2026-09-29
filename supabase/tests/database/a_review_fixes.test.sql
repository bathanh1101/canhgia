-- Phase 02a review fixes: C1 held tracking, W1 overlap, W2 stale page, W3 adjustment+order, W4 column grants,
-- W5 null-IP, W6 device cap, W7 referral cap.
begin;
create extension if not exists pgtap with schema extensions;
select plan(21);

insert into public.merchants (id, name, at_campaign_id, hold_days) values ('shopee', 'Shopee', 'shopee', 30)
  on conflict (id) do update set at_campaign_id = excluded.at_campaign_id, hold_days = excluded.hold_days;
insert into public.cashback_rules (merchant_id, category_key, user_share_bps) values (null, null, 5000), ('shopee', null, 10000)
  on conflict (merchant_id, category_key) do update set user_share_bps = excluded.user_share_bps;
insert into auth.users (id, email) values
  ('a0000000-0000-0000-0000-00000000000a', 'a@x.io'), ('b0000000-0000-0000-0000-00000000000b', 'b@x.io'),
  ('c0000000-0000-0000-0000-00000000000c', 'c@x.io');
insert into public.admins (user_id) values ('c0000000-0000-0000-0000-00000000000c');
insert into auth.users (id, email, raw_user_meta_data)
  select 'd0000000-0000-0000-0000-00000000000d', 'd@x.io', jsonb_build_object('referral_code', referral_code)
    from public.profiles where id = 'b0000000-0000-0000-0000-00000000000b';

create function pg_temp.mk(p_conv bigint, p_st int, p_conf int, p_comm bigint, p_upd text, p_utm text default null,
  p_value bigint default 100000) returns jsonb
language sql as $f$
  select jsonb_build_object('conversion_id', p_conv, 'merchant', 'shopee', 'status', p_st, 'is_confirmed', p_conf,
    'commission', p_comm, 'transaction_value', p_value, 'update_time', p_upd, 'utm_content', p_utm, 'product_name', 'sp')
$f$;
create function pg_temp.wal(p_user uuid) returns text language sql as
  $f$ select held_vnd || '/' || available_vnd from public.wallets where user_id = p_user $f$;

-- C1 + W1: held tracked per row; a due-but-unpromoted row must not corrupt held when the same key moves again
insert into public.orders (id, source, merchant_id, transaction_id, user_id, credit_state) values
  ('e0000000-0000-0000-0000-000000000001', 'manual', 'shopee', 'K1', 'a0000000-0000-0000-0000-00000000000a', 'credited');
insert into public.wallet_ledger (user_id, entry_type, amount_vnd, order_id, idempotency_key, available_at) values
  ('a0000000-0000-0000-0000-00000000000a', 'cashback_credit', 100, 'e0000000-0000-0000-0000-000000000001', 'c1a', now() + interval '30 days');
alter table public.wallet_ledger disable trigger wallet_ledger_guard;
update public.wallet_ledger set available_at = now() - interval '1 minute' where idempotency_key = 'c1a';
alter table public.wallet_ledger enable trigger wallet_ledger_guard;
insert into public.wallet_ledger (user_id, entry_type, amount_vnd, order_id, idempotency_key, available_at) values
  ('a0000000-0000-0000-0000-00000000000a', 'cashback_credit', 50, 'e0000000-0000-0000-0000-000000000001', 'c1b', now() - interval '1 minute');
select is(pg_temp.wal('a0000000-0000-0000-0000-00000000000a'), '100/50', 'C1: due row still held, new delta straight to available');
insert into public.wallet_ledger (user_id, entry_type, amount_vnd, order_id, idempotency_key) values
  ('a0000000-0000-0000-0000-00000000000a', 'cashback_reversal', -30, 'e0000000-0000-0000-0000-000000000001', 'c1c');
select is(pg_temp.wal('a0000000-0000-0000-0000-00000000000a'), '70/50', 'C1: reversal consumes the held row first');
select is(public.promote_withdrawable(), 1, 'C1: promote moves the due row');
select is(pg_temp.wal('a0000000-0000-0000-0000-00000000000a'), '0/120', 'C1: promote moves only the remaining held amount');
select is(public.promote_withdrawable(), 0, 'W1: re-run promotes nothing');
select is(pg_temp.wal('a0000000-0000-0000-0000-00000000000a'), '0/120', 'W1: re-run leaves the wallet unchanged');
select is_empty($$select * from public.check_wallet_drift() where user_id = 'a0000000-0000-0000-0000-00000000000a'$$, 'C1: no drift');

-- W2: stale page never regresses newer state
select set_config('t.utm', (select utm_content from public.create_click('b0000000-0000-0000-0000-00000000000b', 'shopee', 'o', 'https://x/r', null, 'app', null)), true);
select ingest.status from public.ingest_at_transactions('t', jsonb_build_array(pg_temp.mk(1, 1, 1, 10000, '2026-09-02T10:00:00Z', current_setting('t.utm')))) ingest;
select results_eq($$select status from public.ingest_at_transactions('t', jsonb_build_array(pg_temp.mk(1, 0, 0, 20000, '2026-09-01T10:00:00Z', current_setting('t.utm'))))$$,
  $$values ('skipped')$$, 'W2: older update_time is skipped');
select results_eq($$select credit_state::text, commission_vnd from public.orders where conversion_id = 1$$, $$values ('credited', 10000::bigint)$$, 'W2: order state unchanged');

-- W3: admin adjustment on an order is not order state
insert into public.wallet_ledger (user_id, entry_type, amount_vnd, order_id, idempotency_key, note)
  select user_id, 'admin_adjustment', 777, id, 'adm:t', 'goodwill' from public.orders where conversion_id = 1;
select ingest.status from public.ingest_at_transactions('t', jsonb_build_array(pg_temp.mk(1, 1, 1, 10000, '2026-09-03T10:00:00Z', current_setting('t.utm')))) ingest;
select is((select count(*)::int from public.wallet_ledger l join public.orders o on o.id = l.order_id where o.conversion_id = 1), 2,
  'W3: re-ingest posts no compensating row for an adjustment');

-- W7: cashback + referral bonus <= commission
select ingest.status from public.ingest_at_transactions('t', jsonb_build_array(pg_temp.mk(2, 1, 1, 10000,
  '2026-09-03T10:00:00Z', (select utm_content from public.create_click('d0000000-0000-0000-0000-00000000000d', 'shopee', 'o', 'https://x/r2', null, 'app', null)), 300000))) ingest;
select results_eq($$select user_cashback_vnd, bonus_vnd from public.orders o, public.referrals r
  where o.conversion_id = 2 and r.referee_id = 'd0000000-0000-0000-0000-00000000000d'$$, $$values (10000::bigint, 0::bigint)$$, 'W7: 100% cashback leaves no room for a bonus');
select is((select count(*)::int from public.wallet_ledger where entry_type = 'referral_bonus'), 0, 'W7: no referral_bonus row');

-- W5: null IP cannot bypass the rate limit
select throws_ok($$select * from public.start_extension_login(repeat('a', 64), null, 'ua')$$, 'P0001', 'invalid_input', 'W5: null ip rejected');

-- W6: device cap
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-0000-0000-00000000000a","role":"authenticated","aal":"aal1"}', true);
select public.register_device('device-' || lpad(g::text, 4, '0'), 'android', 'P') from generate_series(1, 12) g;
select is((select count(*)::int from public.user_devices), 10, 'W6: at most 10 devices per user');
select ok(exists (select 1 from public.user_devices where device_hash = encode(extensions.digest('device-0012', 'sha256'), 'hex')), 'W6: newest device kept');

-- W4: sensitive columns are not selectable by the owner
select throws_ok($$select risk_level from public.withdrawals$$, '42501', null, 'W4: withdrawals.risk_level hidden');
select throws_ok($$select commission_vnd from public.orders$$, '42501', null, 'W4: orders.commission_vnd hidden');
select throws_ok($$select created_by from public.wallet_ledger$$, '42501', null, 'W4: wallet_ledger.created_by hidden');
select lives_ok($$select amount, status from public.withdrawals; select user_cashback_vnd from public.orders; select amount_vnd from public.wallet_ledger$$, 'W4: business columns readable');
select is((select count(*)::int from public.admin_withdrawals), 0, 'W4: admin view empty for a non-admin');
reset role;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"c0000000-0000-0000-0000-00000000000c","role":"authenticated","aal":"aal2"}', true);
select ok((select count(*) >= 0 from public.admin_withdrawals) and (select count(*) >= 1 from public.admin_orders), 'W4: admin views expose full rows to an aal2 admin');
reset role;

select * from finish();
rollback;
