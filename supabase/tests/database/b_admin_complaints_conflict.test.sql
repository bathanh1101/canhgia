begin;
create extension if not exists pgtap with schema extensions;
grant execute on all functions in schema extensions to public;
select plan(46);

insert into auth.users (id, email) values
  ('a0000000-0000-0000-0000-0000000000c1', 'u@x.io'), ('a0000000-0000-0000-0000-0000000000c2', 'ad1@x.io'),
  ('a0000000-0000-0000-0000-0000000000c3', 'ad2@x.io'), ('a0000000-0000-0000-0000-0000000000c4', 'v@x.io');
insert into public.admins (user_id) values ('a0000000-0000-0000-0000-0000000000c2'), ('a0000000-0000-0000-0000-0000000000c3');
select set_config('t.u', '{"sub":"a0000000-0000-0000-0000-0000000000c1","role":"authenticated","aal":"aal1"}', true);
select set_config('t.ad1', '{"sub":"a0000000-0000-0000-0000-0000000000c2","role":"authenticated","aal":"aal2"}', true);
select set_config('t.ad2', '{"sub":"a0000000-0000-0000-0000-0000000000c3","role":"authenticated","aal":"aal2"}', true);
insert into storage.objects (bucket_id, name) values
  ('complaints', 'a0000000-0000-0000-0000-0000000000c1/a.jpg'), ('complaints', 'a0000000-0000-0000-0000-0000000000c1/b.jpg'),
  ('complaints', 'a0000000-0000-0000-0000-0000000000c4/x.jpg');
create temp table ids (k text primary key, v text);
grant all on ids to public;

-- ---- submit_missing_order (as U)
set local role authenticated;
select set_config('request.jwt.claims', current_setting('t.u'), true);
select throws_ok($$select public.submit_missing_order('shopee', 'AB-1234', current_date - 3, 100000, array['a0000000-0000-0000-0000-0000000000c4/x.jpg'])$$,
  'P0001', 'invalid_input', 'image under another user prefix rejected');
select throws_ok($$select public.submit_missing_order('shopee', 'AB-1234', current_date - 3, 100000, array['a0000000-0000-0000-0000-0000000000c1/missing.jpg'])$$,
  'P0001', 'invalid_input', 'image that does not exist rejected');
select throws_ok($$select public.submit_missing_order('shopee', 'AB-1234', current_date - 3, 100000, '{}')$$, 'P0001', 'invalid_input', 'no image rejected');
select throws_ok($$select public.submit_missing_order('shopee', 'AB-1234', current_date + 1, 100000, array['a0000000-0000-0000-0000-0000000000c1/a.jpg'])$$,
  'P0001', 'invalid_input', 'future purchase rejected');
select throws_ok($$select public.submit_missing_order('shopee', 'AB-1234', current_date - 70, 100000, array['a0000000-0000-0000-0000-0000000000c1/a.jpg'])$$,
  'P0001', 'invalid_input', 'older than 60 days rejected');
select throws_ok($$select public.submit_missing_order('agoda', 'AB-1234', current_date - 3, 100000, array['a0000000-0000-0000-0000-0000000000c1/a.jpg'])$$,
  'P0001', 'invalid_input', 'inactive merchant rejected');
select throws_ok($$select public.submit_missing_order('shopee', '--', current_date - 3, 100000, array['a0000000-0000-0000-0000-0000000000c1/a.jpg'])$$,
  'P0001', 'invalid_input', 'order code without alphanumerics rejected');
insert into ids select 'big', public.submit_missing_order('shopee', 'big-0001', current_date - 3, 5000000, array['a0000000-0000-0000-0000-0000000000c1/a.jpg']);
select alike((select v from ids where k = 'big'), 'KN-%', 'returns public code KN-...');
select throws_ok($$select public.submit_missing_order('shopee', 'BIG 0001', current_date - 3, 100000, array['a0000000-0000-0000-0000-0000000000c1/b.jpg'])$$,
  'P0001', 'invalid_input', 'duplicate order code (normalised) rejected');
insert into ids select 'small', public.submit_missing_order('shopee', 'SMALL01', current_date - 5, 500000, array['a0000000-0000-0000-0000-0000000000c1/b.jpg']);
insert into ids select 'dup', public.submit_missing_order('tiki', 'DUP-0001', current_date - 5, 300000, array['a0000000-0000-0000-0000-0000000000c1/b.jpg']);
insert into ids select 'rej', public.submit_missing_order('tiki', 'REJ-0001', current_date - 5, 300000, array['a0000000-0000-0000-0000-0000000000c1/b.jpg']);
insert into ids select 'x5', public.submit_missing_order('lazada', 'X5-0001', current_date - 5, 300000, array['a0000000-0000-0000-0000-0000000000c1/b.jpg']);
select throws_ok($$select public.submit_missing_order('lazada', 'X6-0001', current_date - 5, 300000, array['a0000000-0000-0000-0000-0000000000c1/b.jpg'])$$,
  'P0001', 'rate_limited', 'sixth open report rejected (cap 5)');
select is((select count(*)::int from public.missing_order_reports), 5, 'user sees own reports only');
reset role;

-- ---- gate: non-admin and aal1 admin are forbidden
create temp table rid as select id, public_code from public.missing_order_reports;
grant all on rid to public;
set local role authenticated;
select set_config('request.jwt.claims', current_setting('t.u'), true);
select throws_ok($$select public.admin_resolve_complaint((select id from rid limit 1), 'rejected', null, 'n')$$, 'P0001', 'forbidden', 'non-admin forbidden');
select throws_ok($$select public.admin_assign_order(gen_random_uuid(), 'a0000000-0000-0000-0000-0000000000c1')$$, 'P0001', 'forbidden', 'assign: non-admin forbidden');
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-0000-0000-0000000000c2","role":"authenticated","aal":"aal1"}', true);
select throws_ok($$select public.admin_resolve_complaint((select id from rid limit 1), 'rejected', null, 'n')$$, 'P0001', 'forbidden', 'admin at aal1 forbidden');

-- ---- 2.500.000 needs a second approver
select set_config('request.jwt.claims', current_setting('t.ad1'), true);
select is(public.admin_resolve_complaint((select id from rid where public_code = (select v from ids where k = 'big')), 'approved', 2500000, 'ok'),
  'requires_second_approver', 'first approval > 2M waits');
select is((select count(*)::int from public.wallet_ledger where entry_type = 'manual_credit'), 0, 'no ledger after first approval');
select throws_ok($$select public.admin_resolve_complaint((select id from rid where public_code = (select v from ids where k = 'big')), 'approved', 2500000, 'ok')$$,
  'P0001', 'forbidden', 'same admin twice -> forbidden');
select set_config('request.jwt.claims', current_setting('t.ad2'), true);
select throws_ok($$select public.admin_resolve_complaint((select id from rid where public_code = (select v from ids where k = 'big')), 'approved', 2400000, 'ok')$$,
  'P0001', 'invalid_input', 'second admin must repeat the same amount');
select is(public.admin_resolve_complaint((select id from rid where public_code = (select v from ids where k = 'big')), 'approved', 2500000, 'ok'),
  'approved', 'second admin executes');
reset role;
select is((select count(*)::int from public.wallet_ledger where entry_type = 'manual_credit' and amount_vnd = 2500000), 1, 'exactly one manual_credit');
select results_eq($$select source::text, transaction_id, user_cashback_vnd, credit_state::text from public.orders where transaction_id = 'big-0001'$$,
  $$values ('manual'::text, 'big-0001', 2500000::bigint, 'credited')$$, 'manual order created from complaint');
select results_eq($$select status, resolution_amount_vnd, resolved_order_id is not null from public.missing_order_reports where public_code = (select v from ids where k = 'big')$$,
  $$values ('approved'::text, 2500000::bigint, true)$$, 'report resolved');
select is((select held_vnd from public.wallets where user_id = 'a0000000-0000-0000-0000-0000000000c1'), 2500000::bigint, 'credit held for hold_days');

-- ---- small complaint, validations
set local role authenticated;
select set_config('request.jwt.claims', current_setting('t.ad1'), true);
select throws_ok($$select public.admin_resolve_complaint((select id from rid where public_code = (select v from ids where k = 'big')), 'approved', 1, 'again')$$,
  'P0001', 'invalid_state', 'resolved complaint cannot be resolved again');
select throws_ok($$select public.admin_resolve_complaint((select id from rid where public_code = (select v from ids where k = 'small')), 'approved', 600000, 'x')$$,
  'P0001', 'invalid_input', 'amount above reported order value rejected');
select throws_ok($$select public.admin_resolve_complaint((select id from rid where public_code = (select v from ids where k = 'small')), 'maybe', 1000, 'x')$$,
  'P0001', 'invalid_input', 'bad decision rejected');
select throws_ok($$select public.admin_resolve_complaint((select id from rid where public_code = (select v from ids where k = 'rej')), 'rejected', null, ' ')$$,
  'P0001', 'invalid_input', 'rejection needs a note');
select is(public.admin_resolve_complaint((select id from rid where public_code = (select v from ids where k = 'rej')), 'rejected', null, 'không hợp lệ'), 'rejected', 'reject');
select is(public.admin_resolve_complaint((select id from rid where public_code = (select v from ids where k = 'small')), 'approved', 100000, 'ok'),
  'approved', '<= 2M: single admin approves');
reset role;

-- AccessTrade order already known -> invalid_state
insert into public.orders (source, conversion_id, merchant_id, transaction_id) values ('accesstrade', 800001, 'tiki', 'DUP0001');
set local role authenticated;
select set_config('request.jwt.claims', current_setting('t.ad1'), true);
select throws_ok($$select public.admin_resolve_complaint((select id from rid where public_code = (select v from ids where k = 'dup')), 'approved', 1000, 'x')$$,
  'P0001', 'invalid_state', 'existing AccessTrade order -> invalid_state');
select is((select count(*)::int from public.admin_audit_log where action = 'resolve_complaint'), 4, 'audit row per successful call (failed calls roll back)');
reset role;

-- ---- late AccessTrade order for another user against the manual claim -> conflict flag, no silent reassignment
select public.create_click('a0000000-0000-0000-0000-0000000000c4', 'shopee', 'https://shopee.vn/p', 'https://shopee.vn/p', null, 'app', null);
select public.ingest_at_transactions('t', (select jsonb_build_array(jsonb_build_object('conversion_id', 800002, 'merchant', 'shopee',
  'status', 0, 'is_confirmed', 0, 'transaction_id', 'SMALL01', 'utm_content', c.utm_content, 'commission', 10000,
  'transaction_value', 500000, 'update_time', now())) from public.clicks c where c.user_id = 'a0000000-0000-0000-0000-0000000000c4'));
select is((select count(*)::int from public.fraud_flags f join public.missing_order_reports r on r.resolved_order_id::text = f.evidence ->> 'manual_order_id'
   where f.type = 'order_claim_conflict' and r.public_code = (select v from ids where k = 'small')), 1, 'conflict flag links to the complaint order');
select is((select user_id from public.orders where transaction_id = 'SMALL01' and source = 'manual'), 'a0000000-0000-0000-0000-0000000000c1'::uuid, 'manual claim not reassigned');

-- ---- admin_assign_order: unmatched -> U, then U -> V
select public.ingest_at_transactions('t', jsonb_build_array(jsonb_build_object('conversion_id', 800003, 'merchant', 'shopee',
  'status', 1, 'is_confirmed', 1, 'transaction_id', 'UNM1', 'commission', 100000, 'transaction_value', 2000000, 'update_time', now())));
insert into ids select 'unm', id::text from public.orders where conversion_id = 800003;
select is((select credit_state::text from public.orders where conversion_id = 800003), 'none', 'unmatched order has no credit');
set local role authenticated;
select set_config('request.jwt.claims', current_setting('t.ad1'), true);
select lives_ok($$select public.admin_assign_order((select v::uuid from ids where k = 'unm'), 'a0000000-0000-0000-0000-0000000000c1')$$, 'assign unmatched');
reset role;
select results_eq($$select credit_state::text, user_cashback_vnd, user_id from public.orders where conversion_id = 800003$$,
  $$values ('credited'::text, 70000::bigint, 'a0000000-0000-0000-0000-0000000000c1'::uuid)$$, 'priced (70% of commission) and credited');
select is((select held_vnd from public.wallets where user_id = 'a0000000-0000-0000-0000-0000000000c1'), 2670000::bigint, 'new owner credited (held)');
set local role authenticated;
select set_config('request.jwt.claims', current_setting('t.ad1'), true);
select lives_ok($$select public.admin_assign_order((select v::uuid from ids where k = 'unm'), 'a0000000-0000-0000-0000-0000000000c4')$$, 're-assign to V');
select throws_ok($$select public.admin_assign_order((select v::uuid from ids where k = 'unm'), 'a0000000-0000-0000-0000-0000000000c4')$$,
  'P0001', 'invalid_state', 'assign to the same owner -> invalid_state');
select throws_ok($$select public.admin_assign_order((select v::uuid from ids where k = 'unm'), gen_random_uuid())$$, 'P0001', 'invalid_input', 'unknown user');
select throws_ok($$select public.admin_assign_order(gen_random_uuid(), 'a0000000-0000-0000-0000-0000000000c4')$$, 'P0001', 'invalid_state', 'unknown order');
reset role;
select is((select held_vnd from public.wallets where user_id = 'a0000000-0000-0000-0000-0000000000c1'), 2600000::bigint, 'old owner reversed (complaint credits stay)');
select is((select held_vnd from public.wallets where user_id = 'a0000000-0000-0000-0000-0000000000c4'), 70000::bigint, 'new owner credited');
select is((select count(*)::int from public.wallet_ledger where order_id = (select v::uuid from ids where k = 'unm') and entry_type = 'cashback_reversal'), 1, 'one reversal row');
select is((select count(*)::int from public.notifications where type = 'order' and data ->> 'order_id' = (select v from ids where k = 'unm')
   and user_id in ('a0000000-0000-0000-0000-0000000000c1', 'a0000000-0000-0000-0000-0000000000c4') and title like 'Đơn hàng %chuyển%'), 1, 'old owner notified');
select is((select count(*)::int from public.check_wallet_drift()), 0, 'no wallet drift after all of the above');

select * from finish();
rollback;
