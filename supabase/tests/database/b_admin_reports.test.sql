begin;
create extension if not exists pgtap with schema extensions;
grant execute on all functions in schema extensions to public;
select plan(58);

insert into auth.users (id, email) values
  ('a0000000-0000-0000-0000-0000000000d1', 'u@x.io'), ('a0000000-0000-0000-0000-0000000000d2', 'v@x.io'),
  ('a0000000-0000-0000-0000-0000000000d3', 'admin@x.io');
insert into public.admins (user_id) values ('a0000000-0000-0000-0000-0000000000d3');
select set_config('t.u', '{"sub":"a0000000-0000-0000-0000-0000000000d1","role":"authenticated","aal":"aal2"}', true);
select set_config('t.ad', '{"sub":"a0000000-0000-0000-0000-0000000000d3","role":"authenticated","aal":"aal2"}', true);
select set_config('t.ad1', '{"sub":"a0000000-0000-0000-0000-0000000000d3","role":"authenticated","aal":"aal1"}', true);

-- ---- fixtures in March 2020 (seed data lives in the present, so numbers are exact)
insert into public.orders (id, source, merchant_id, transaction_id, user_id, value_vnd, commission_vnd, user_cashback_vnd, credit_state, order_time) values
  ('d0000000-0000-0000-0000-000000000001', 'manual', 'shopee', 'F1', 'a0000000-0000-0000-0000-0000000000d1', 1000000, 50000, 35000, 'credited', '2020-03-10 05:00+00'),
  ('d0000000-0000-0000-0000-000000000002', 'manual', 'tiki', 'F2', 'a0000000-0000-0000-0000-0000000000d1', 500000, 20000, 14000, 'pending', '2020-03-11 05:00+00'),
  ('d0000000-0000-0000-0000-000000000003', 'manual', 'shopee', 'F3', null, 300000, 10000, 0, 'none', '2020-03-12 05:00+00'),
  ('d0000000-0000-0000-0000-000000000004', 'manual', 'shopee', 'F4', 'a0000000-0000-0000-0000-0000000000d2', 999999, 99999, 1, 'cancelled', '2020-03-13 05:00+00'),
  ('d0000000-0000-0000-0000-000000000005', 'manual', 'tiki', 'F5', 'a0000000-0000-0000-0000-0000000000d2', 2000000, 150000, 105000, 'credited', '2020-03-31 17:30+00');
insert into public.wallet_ledger (user_id, entry_type, amount_vnd, order_id, idempotency_key, created_at) values
  ('a0000000-0000-0000-0000-0000000000d1', 'manual_credit', 35000, 'd0000000-0000-0000-0000-000000000001', 'rp1', '2020-03-11 05:00+00'),
  ('a0000000-0000-0000-0000-0000000000d1', 'admin_adjustment', -5000, null, 'rp2', '2020-03-12 05:00+00'),
  ('a0000000-0000-0000-0000-0000000000d1', 'withdrawal_debit', -10000, null, 'rp3', '2020-03-12 06:00+00');
insert into public.sync_errors (job, error) values ('t', 'e1'), ('t', 'e2');

-- ---- every admin fn: forbidden for non-admin and for admin below aal2
set local role authenticated;
select set_config('request.jwt.claims', current_setting('t.u'), true);
select throws_ok(c, 'P0001', 'forbidden', 'non-admin: ' || left(c, 40)) from unnest(array[
  $$select * from public.admin_overview('2020-03-01', '2020-03-31')$$,
  $$select * from public.admin_monthly_series(3)$$,
  $$select * from public.admin_merchant_mix('2020-03-01', '2020-03-31')$$,
  $$select public.admin_user_stats(30)$$,
  $$select * from public.admin_top_users(5)$$,
  $$select public.admin_upsert_cashback_rule('shopee', null, 100, true, null)$$,
  $$select public.admin_update_vip_tier('bac', 100, 1)$$,
  $$select public.admin_set_setting('min_withdraw_vnd', '1')$$,
  $$select public.admin_set_user_lock('a0000000-0000-0000-0000-0000000000d1', true, 'x')$$,
  $$select public.admin_update_flag(1, 'dismissed')$$
]) c;
select set_config('request.jwt.claims', current_setting('t.ad1'), true);
select throws_ok($$select * from public.admin_overview('2020-03-01', '2020-03-31')$$, 'P0001', 'forbidden', 'admin at aal1 forbidden');

-- ---- reports
select set_config('request.jwt.claims', current_setting('t.ad'), true);
select results_eq($$select gmv_vnd, commission_vnd, pending_commission_vnd, paid_to_users_vnd, net_vnd, unmatched_count, unmatched_ratio
  from public.admin_overview('2020-03-01', '2020-03-31')$$,
  $$values (1500000::bigint, 50000::bigint, 20000::bigint, 30000::bigint, 20000::bigint, 1, 0.2500::numeric)$$,
  'overview March (F5 falls on 1 April VN): gmv (pending+credited), credited commission, paid = credits net of adjustments, unmatched share');
select is((select sync_errors_24h from public.admin_overview('2020-03-01', '2020-03-31')), (select count(*)::int from public.sync_errors where created_at > now() - interval '24 hours'), 'sync_errors_24h');
select results_eq($$select gmv_vnd from public.admin_overview('2020-05-01', '2020-05-31')$$, $$values (0::bigint)$$, 'empty range -> zeros');
select is((select unmatched_ratio from public.admin_overview('2020-05-01', '2020-05-31')), 0::numeric, 'empty range ratio 0 (no division by zero)');
select results_eq($$select gmv_vnd from public.admin_overview('2020-03-31', '2020-03-31')$$, $$values (0::bigint)$$, 'Asia/Ho_Chi_Minh day edge: 17:30Z on 31st belongs to 1 April');
select results_eq($$select gmv_vnd from public.admin_overview('2020-04-01', '2020-04-01')$$, $$values (2000000::bigint)$$, '... and shows up on 1 April');
select throws_ok($$select * from public.admin_overview('2020-04-01', '2020-03-01')$$, 'P0001', 'invalid_input', 'inverted range rejected');
select throws_ok($$select * from public.admin_overview(null, '2020-03-01')$$, 'P0001', 'invalid_input', 'null bound rejected');
select results_eq($$select merchant_id, commission_vnd, share from public.admin_merchant_mix('2020-03-01', '2020-04-30') order by commission_vnd desc$$,
  $$values ('tiki'::text, 150000::bigint, 0.7500::numeric), ('shopee', 50000::bigint, 0.2500::numeric)$$, 'merchant mix: credited commission and share');
select is((select count(*)::int from public.admin_monthly_series(100)), 36, 'months clamped to 36');
select is((select count(*)::int from public.admin_monthly_series(0)), 1, 'months floor 1');
select ok((select bool_and(net_vnd = commission_vnd - paid_vnd) from public.admin_monthly_series(12)), 'series: net = commission - paid');
select results_eq($$select gmv_vnd, cashback_vnd, orders from public.admin_top_users(100) where user_id = 'a0000000-0000-0000-0000-0000000000d1'$$,
  $$values (1000000::bigint, 35000::bigint, 1)$$, 'top users: credited orders only');
select is((select count(*)::int from public.admin_top_users(1)), 1, 'top users limit honoured');
select is((select count(*)::int from public.admin_top_users(100000)), (select least(100, count(distinct user_id))::int from public.orders where credit_state = 'credited' and user_id is not null), 'top users limit clamped to 100');
reset role;

-- user stats: cohort created 45 days ago, one of two active >= 30 days after signup
update public.profiles set created_at = now() - interval '45 days' where id in ('a0000000-0000-0000-0000-0000000000d1', 'a0000000-0000-0000-0000-0000000000d2');
insert into public.user_activity_days (user_id, day) values
  ('a0000000-0000-0000-0000-0000000000d1', private.vn_today() - 5), ('a0000000-0000-0000-0000-0000000000d1', private.vn_today()),
  ('a0000000-0000-0000-0000-0000000000d2', private.vn_today() - 44);
set local role authenticated;
select set_config('request.jwt.claims', current_setting('t.ad'), true);
select is((select (public.admin_user_stats(30) ->> 'd30_retention')::numeric), 0.5000::numeric, 'd30 retention = retained / cohort');
select ok((public.admin_user_stats(30) ? 'new_users_month') and (public.admin_user_stats(30) ? 'dau'), 'user stats keys');
select cmp_ok(jsonb_array_length(public.admin_user_stats(1) -> 'dau'), '=', 1, 'dau window clamps to requested days');

-- ---- VIP / cashback rules caps (default rule 70% + max VIP 20% = 90%)
select lives_ok($$select public.admin_update_vip_tier('vang', 3000, 10000000)$$, 'vip bonus 30% + 70% share = 100% ok');
select throws_ok($$select public.admin_update_vip_tier('vang', 3001, 10000000)$$, 'P0001', 'invalid_input', 'share + vip > 100% rejected');
select throws_ok($$select public.admin_update_vip_tier('nope', 0, 0)$$, 'P0001', 'invalid_input', 'unknown tier');
select throws_ok($$select public.admin_update_vip_tier('vang', -1, 0)$$, 'P0001', 'invalid_input', 'negative bonus');
select lives_ok($$select public.admin_update_vip_tier('vang', 1000, 10000000)$$, 'restore');
select throws_ok($$select public.admin_upsert_cashback_rule('shopee', null, 8001, true, 'too high')$$, 'P0001', 'invalid_input', 'share + max vip > 100% rejected');
select throws_ok($$select public.admin_upsert_cashback_rule('shopee', null, 10001, true, null)$$, 'P0001', 'invalid_input', 'share > 10000 rejected');
select throws_ok($$select public.admin_upsert_cashback_rule('ghost', null, 100, true, null)$$, 'P0001', 'invalid_input', 'unknown merchant');
select results_eq($$select public.admin_upsert_cashback_rule('shopee', null, 5000, true, 'promo') = public.admin_upsert_cashback_rule('shopee', '', 6000, true, null)$$,
  $$values (true)$$, 'upsert hits the same (merchant, null-category) row');
select is((select user_share_bps from public.cashback_rules where merchant_id = 'shopee' and category_key is null), 6000, 'rule updated in place');
select lives_ok($$select public.admin_upsert_cashback_rule('shopee', 'fashion', 4000, false, 'off')$$, 'disable a category');
select is((select user_share_bps from public.cashback_rules where merchant_id = 'shopee' and category_key = 'fashion'), 0, 'disabled rule stores share 0 (ingest honours it)');
select is((select count(*)::int from public.admin_audit_log where action = 'upsert_cashback_rule'), 3, 'rule changes audited');

-- ---- settings
select lives_ok($$select public.admin_set_setting('min_withdraw_vnd', '60000')$$, 'set numeric setting');
select is((public.get_public_settings() ->> 'min_withdraw_vnd')::int, 60000, 'public settings reflect the change');
select throws_ok($$select public.admin_set_setting('min_withdraw_vnd', '"abc"')$$, 'P0001', 'invalid_input', 'wrong type rejected');
select throws_ok($$select public.admin_set_setting('min_withdraw_vnd', '-5')$$, 'P0001', 'invalid_input', 'negative number rejected');
select throws_ok($$select public.admin_set_setting('made_up_key', '1')$$, 'P0001', 'invalid_input', 'unknown key rejected');
select lives_ok($$select public.admin_set_setting('auto_payout_enabled', 'false')$$, 'boolean setting');
select lives_ok($$select public.admin_set_setting('withdraw_eta_text', '"Trong ngày"')$$, 'text setting');

-- ---- lock / flags
select lives_ok($$select public.admin_set_user_lock('a0000000-0000-0000-0000-0000000000d1', true, 'nghi ngờ gian lận')$$, 'lock user');
select ok((select locked_at is not null from public.profiles where id = 'a0000000-0000-0000-0000-0000000000d1'), 'locked_at set');
select is((select lock_reason from public.user_risk where user_id = 'a0000000-0000-0000-0000-0000000000d1'), 'nghi ngờ gian lận', 'reason recorded');
select throws_ok($$select public.admin_set_user_lock('a0000000-0000-0000-0000-0000000000d1', true, ' ')$$, 'P0001', 'invalid_input', 'lock needs a reason');
select lives_ok($$select public.admin_set_user_lock('a0000000-0000-0000-0000-0000000000d1', false, null)$$, 'unlock');
select throws_ok($$select public.admin_set_user_lock(gen_random_uuid(), true, 'x')$$, 'P0001', 'invalid_input', 'unknown user');
reset role;
select private.flag('a0000000-0000-0000-0000-0000000000d1', 'abnormal_clicks', 20, '{}', 'rep-flag-1');
set local role authenticated;
select set_config('request.jwt.claims', current_setting('t.ad'), true);
select lives_ok($$select public.admin_update_flag((select id from public.fraud_flags where dedupe_key = 'rep-flag-1'), 'actioned')$$, 'action a flag');
select is((select resolved_by from public.fraud_flags where dedupe_key = 'rep-flag-1'), 'a0000000-0000-0000-0000-0000000000d3'::uuid, 'resolver recorded');
select throws_ok($$select public.admin_update_flag(-1, 'dismissed')$$, 'P0001', 'invalid_state', 'unknown flag');
reset role;

select * from finish();
rollback;
