begin;
create extension if not exists pgtap with schema extensions;
select plan(36);

-- fixtures -------------------------------------------------------------------
insert into public.merchants (id, name, at_campaign_id, hold_days) values
  ('shopee', 'Shopee', 'shopee', 30), ('zero', 'ZeroHold', 'zerohold', 0);
insert into public.cashback_rules (merchant_id, category_key, user_share_bps) values (null, null, 5000);
insert into auth.users (id, email) values
  ('a0000000-0000-0000-0000-00000000000a', 'a@x.io'), ('b0000000-0000-0000-0000-00000000000b', 'b@x.io');
insert into auth.users (id, email, raw_user_meta_data)
  select 'c0000000-0000-0000-0000-00000000000c', 'c@x.io', jsonb_build_object('referral_code', referral_code)
    from public.profiles where id = 'a0000000-0000-0000-0000-00000000000a';

create function pg_temp.mk(p_conv bigint, p_st int, p_conf int, p_comm bigint, p_upd text, p_utm text default null,
  p_merchant text default 'shopee', p_txn text default null, p_value bigint default 100000) returns jsonb
language sql as $f$
  select jsonb_build_object('conversion_id', p_conv, 'merchant', p_merchant, 'status', p_st, 'is_confirmed', p_conf,
    'commission', p_comm, 'transaction_value', p_value, 'update_time', p_upd, 'utm_content', p_utm, 'transaction_id', p_txn,
    'product_name', 'sp')
$f$;
create function pg_temp.utm(p_user uuid, p_merchant text default 'shopee') returns text
language sql as $f$ select utm_content from public.create_click(p_user, p_merchant, 'https://x/o', 'https://x/r', null, 'app', null) $f$;

select set_config('t.utm_a', pg_temp.utm('a0000000-0000-0000-0000-00000000000a'), true);
select set_config('t.utm_b', pg_temp.utm('b0000000-0000-0000-0000-00000000000b'), true);
select set_config('t.utm_z', pg_temp.utm('b0000000-0000-0000-0000-00000000000b', 'zero'), true);
select set_config('t.utm_c', pg_temp.utm('c0000000-0000-0000-0000-00000000000c'), true);
select ok(current_setting('t.utm_a') ~ '^u\d+c\d+$', 'click yields utm_content u<short>c<click>');

-- lifecycle ---------------------------------------------------------------------
select results_eq($$select status from public.ingest_at_transactions('t', jsonb_build_array(
  pg_temp.mk(1, 0, 0, 10000, '2026-09-01T10:00:00Z', current_setting('t.utm_a'))))$$, $$values ('inserted')$$, 'new pending row inserted');
select results_eq($$select credit_state::text, user_cashback_vnd, user_share_bps from public.orders where conversion_id = 1$$,
  $$values ('pending', 5000::bigint, 5000)$$, 'pending order snapshots share; cashback = 50% of commission');
select is((select pending_vnd from public.wallets where user_id = 'a0000000-0000-0000-0000-00000000000a'), 5000::bigint, 'pending_vnd tracks pending order');
select is((select count(*)::int from public.notifications where user_id = 'a0000000-0000-0000-0000-00000000000a' and type = 'order'), 1, 'notification on first state');

select results_eq($$select status from public.ingest_at_transactions('t', jsonb_build_array(
  pg_temp.mk(1, 1, 1, 10000, '2026-09-02T10:00:00Z', current_setting('t.utm_a'))))$$, $$values ('updated')$$, 'approval updates');
select results_eq($$select held_vnd, available_vnd, pending_vnd from public.wallets where user_id = 'a0000000-0000-0000-0000-00000000000a'$$,
  $$values (5000::bigint, 0::bigint, 0::bigint)$$, 'credited -> held (not withdrawable), pending cleared');
select ok((select withdrawable_at from public.orders where conversion_id = 1) = (select confirmed_time + interval '30 days' from public.orders where conversion_id = 1),
  'withdrawable_at = confirmed_time + hold_days');

-- replay: identical ledger
select results_eq($$select status from public.ingest_at_transactions('t', jsonb_build_array(
  pg_temp.mk(1, 1, 1, 10000, '2026-09-02T10:00:00Z', current_setting('t.utm_a'))))$$, $$values ('skipped')$$, 'replay skipped');
select is((select count(*)::int from public.wallet_ledger where order_id = (select id from public.orders where conversion_id = 1)), 1, 'replay adds no ledger rows');

-- flip-flop: reject -> approve -> commission edit; ledger sum always = target
select ingest.status from public.ingest_at_transactions('t', jsonb_build_array(pg_temp.mk(1, 2, 1, 10000, '2026-09-03T10:00:00Z', current_setting('t.utm_a')))) ingest;
select results_eq($$select credit_state::text from public.orders where conversion_id = 1$$, $$values ('reversed')$$, 'reject after credit -> reversed');
select results_eq($$select coalesce(sum(amount_vnd), 0)::bigint, (select held_vnd from public.wallets where user_id = 'a0000000-0000-0000-0000-00000000000a')
  from public.wallet_ledger where order_id = (select id from public.orders where conversion_id = 1)$$, $$values (0::bigint, 0::bigint)$$,
  'reversal while held: ledger 0, held 0, available untouched');
select ingest.status from public.ingest_at_transactions('t', jsonb_build_array(pg_temp.mk(1, 1, 1, 10000, '2026-09-04T10:00:00Z', current_setting('t.utm_a')))) ingest;
select is((select sum(amount_vnd)::bigint from public.wallet_ledger where order_id = (select id from public.orders where conversion_id = 1)),
  (select user_cashback_vnd from public.orders where conversion_id = 1), 're-approve: ledger sum = user_cashback');
select ingest.status from public.ingest_at_transactions('t', jsonb_build_array(pg_temp.mk(1, 1, 1, 12000, '2026-09-05T10:00:00Z', current_setting('t.utm_a')))) ingest;
select is((select sum(amount_vnd)::bigint from public.wallet_ledger where order_id = (select id from public.orders where conversion_id = 1)), 6000::bigint,
  'commission edit posts the delta');
select is((select held_vnd from public.wallets where user_id = 'a0000000-0000-0000-0000-00000000000a'), 6000::bigint, 'held follows');

-- reversal after promotion with 0 available -> no ledger row + negative_balance_risk
select ingest.status from public.ingest_at_transactions('t', jsonb_build_array(pg_temp.mk(2, 1, 1, 10000, '2026-09-01T10:00:00Z', current_setting('t.utm_z'), 'zero'))) ingest;
select is((select available_vnd from public.wallets where user_id = 'b0000000-0000-0000-0000-00000000000b'), 5000::bigint, 'hold_days=0 -> straight to available');
insert into public.wallet_ledger (user_id, entry_type, amount_vnd, idempotency_key) values ('b0000000-0000-0000-0000-00000000000b', 'withdrawal_debit', -5000, 'spent');
select ingest.status from public.ingest_at_transactions('t', jsonb_build_array(pg_temp.mk(2, 2, 1, 10000, '2026-09-02T10:00:00Z', current_setting('t.utm_z'), 'zero'))) ingest;
select is((select count(*)::int from public.wallet_ledger where order_id = (select id from public.orders where conversion_id = 2)), 1, 'no reversal row when available is short');
select is((select count(*)::int from public.fraud_flags where type = 'negative_balance_risk' and user_id = 'b0000000-0000-0000-0000-00000000000b'), 1, 'negative_balance_risk flagged');
select ok(exists (select 1 from public.orders where conversion_id = 2 and credit_state = 'reversed'), 'order still reversed');

-- malformed row in a 100-row page: 99 ingested + 1 sync_errors
create temp table page on commit drop as
  select * from public.ingest_at_transactions('page', (select jsonb_agg(
    pg_temp.mk(1000 + g, case when g = 50 then 9 else 0 end, 0, 1000, '2026-09-01T10:00:00Z')) from generate_series(1, 100) g));
select is((select count(*)::int from page where status <> 'error'), 99, '99 rows ingested');
select is((select count(*)::int from page where status = 'error'), 1, '1 error row');
select is((select count(*)::int from public.sync_errors where job = 'page' and conversion_id = 1050), 1, 'error row in sync_errors');
select is((select count(*)::int from page where status = 'unmatched'), 99, 'no utm -> unmatched');
select throws_ok($$select * from public.ingest_at_transactions('t', '{}')$$, 'P0001', 'invalid_input', 'non-array page rejected');

-- manual order attach keeps credited + resolution amount
insert into public.orders (id, source, merchant_id, transaction_id, user_id, credit_state, user_cashback_vnd, confirmed_time, withdrawable_at)
  values ('d0000000-0000-0000-0000-000000000001', 'manual', 'shopee', 'AB-123', 'a0000000-0000-0000-0000-00000000000a', 'credited', 2000, now(), now() - interval '1 day');
insert into public.wallet_ledger (user_id, entry_type, amount_vnd, order_id, idempotency_key)
  values ('a0000000-0000-0000-0000-00000000000a', 'manual_credit', 2000, 'd0000000-0000-0000-0000-000000000001', 'man1');
select results_eq($$select status from public.ingest_at_transactions('t', jsonb_build_array(
  pg_temp.mk(3, 1, 1, 50000, '2026-09-05T10:00:00Z', current_setting('t.utm_a'), 'shopee', 'ab123'))) $$, $$values ('updated')$$, 'AT row attaches to manual order');
select results_eq($$select conversion_id, user_cashback_vnd, credit_state::text from public.orders where id = 'd0000000-0000-0000-0000-000000000001'$$,
  $$values (3::bigint, 2000::bigint, 'credited')$$, 'manual order keeps resolution amount');
select is((select sum(amount_vnd)::bigint from public.wallet_ledger where order_id = 'd0000000-0000-0000-0000-000000000001'), 2000::bigint, 'no double credit');
select ingest.status from public.ingest_at_transactions('t', jsonb_build_array(pg_temp.mk(3, 2, 1, 50000, '2026-09-06T10:00:00Z', current_setting('t.utm_a'), 'shopee', 'ab123'))) ingest;
select is((select sum(amount_vnd)::bigint from public.wallet_ledger where order_id = 'd0000000-0000-0000-0000-000000000001'), 0::bigint, 'AT status 2 reverses manual order');
select ok(exists (select 1 from public.wallet_ledger where idempotency_key like 'ord:d0000000-0000-0000-0000-000000000001:%' and entry_type = 'manual_reversal'), 'manual_reversal entry type');

-- claim conflict: never silently reassign
insert into public.orders (id, source, merchant_id, transaction_id, user_id, credit_state, user_cashback_vnd)
  values ('d0000000-0000-0000-0000-000000000002', 'manual', 'shopee', 'CD-9', 'a0000000-0000-0000-0000-00000000000a', 'pending', 0);
select ingest.status from public.ingest_at_transactions('t', jsonb_build_array(pg_temp.mk(4, 0, 0, 10000, '2026-09-05T10:00:00Z', current_setting('t.utm_b'), 'shopee', 'cd9'))) ingest;
select ok((select conversion_id is null and user_id = 'a0000000-0000-0000-0000-00000000000a' from public.orders where id = 'd0000000-0000-0000-0000-000000000002'), 'manual order untouched');
select ok(exists (select 1 from public.orders where conversion_id = 4 and user_id = 'b0000000-0000-0000-0000-00000000000b' and source = 'accesstrade'), 'new AT order for the click owner');
select is((select count(*)::int from public.fraud_flags where type = 'order_claim_conflict'), 1, 'order_claim_conflict flagged');

-- referral: qualification then reversal
select ingest.status from public.ingest_at_transactions('t', jsonb_build_array(pg_temp.mk(5, 1, 1, 30000, '2026-09-05T10:00:00Z', current_setting('t.utm_c'), 'shopee', null, 300000))) ingest;
select results_eq($$select status::text, bonus_vnd from public.referrals where referee_id = 'c0000000-0000-0000-0000-00000000000c'$$,
  $$values ('rewarded', 9000::bigint)$$, 'bonus = min(30000, 30% of commission)');
select ok(exists (select 1 from public.wallet_ledger where entry_type = 'referral_bonus' and amount_vnd = 9000 and user_id = 'a0000000-0000-0000-0000-00000000000a' and available_at > now() + interval '29 days'), 'referral_bonus held 30d');
select ingest.status from public.ingest_at_transactions('t', jsonb_build_array(pg_temp.mk(5, 2, 1, 30000, '2026-09-06T10:00:00Z', current_setting('t.utm_c'), 'shopee', null, 300000))) ingest;
select results_eq($$select r.status::text, (select coalesce(sum(l.amount_vnd), 0) from public.wallet_ledger l where l.referral_id = r.id)::bigint
  from public.referrals r where r.referee_id = 'c0000000-0000-0000-0000-00000000000c'$$, $$values ('void', 0::bigint)$$, 'reversed order voids referral bonus');

select is_empty($$select * from public.check_wallet_drift()$$, 'no wallet drift after all scenarios');
select * from finish();
rollback;
