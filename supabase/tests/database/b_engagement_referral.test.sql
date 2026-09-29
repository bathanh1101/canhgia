begin;
create extension if not exists pgtap with schema extensions;
grant execute on all functions in schema extensions to public; -- 000100 revokes default EXECUTE; pgtap must survive role switches
select plan(42);

insert into auth.users (id, email) values
  ('a0000000-0000-0000-0000-0000000000a1', 'r@x.io'), ('a0000000-0000-0000-0000-0000000000a2', 'e@x.io'),
  ('a0000000-0000-0000-0000-0000000000a3', 'x@x.io');
update public.profiles set referral_code = 'REFR0001' where id = 'a0000000-0000-0000-0000-0000000000a1';
select set_config('t.r', '{"sub":"a0000000-0000-0000-0000-0000000000a1","role":"authenticated","aal":"aal1"}', true);
select set_config('t.e', '{"sub":"a0000000-0000-0000-0000-0000000000a2","role":"authenticated","aal":"aal1"}', true);
select set_config('t.x', '{"sub":"a0000000-0000-0000-0000-0000000000a3","role":"authenticated","aal":"aal1"}', true);

-- ---- referral binding (as E)
set local role authenticated;
select set_config('request.jwt.claims', current_setting('t.e'), true);
select throws_ok($$select public.bind_referral('nope')$$, 'P0001', 'code_invalid', 'unknown code');
select throws_ok($$select public.bind_referral((select referral_code from public.profiles where id = auth.uid()))$$, 'P0001', 'code_invalid', 'own code rejected');
select lives_ok($$select public.bind_referral('refr0001')$$, 'bind (case-insensitive)');
select throws_ok($$select public.bind_referral('REFR0001')$$, 'P0001', 'code_invalid', 'second bind rejected');
reset role;
select is((select referred_by from public.profiles where id = 'a0000000-0000-0000-0000-0000000000a2'),
  'a0000000-0000-0000-0000-0000000000a1'::uuid, 'referred_by set');
select is((select referrer_id from public.referrals where referee_id = 'a0000000-0000-0000-0000-0000000000a2'),
  'a0000000-0000-0000-0000-0000000000a1'::uuid, 'referral row created');

-- loop + expiry (as R and X)
set local role authenticated;
select set_config('request.jwt.claims', current_setting('t.r'), true);
select throws_ok($$select public.bind_referral((select referral_code from public.profiles where id = 'a0000000-0000-0000-0000-0000000000a2'))$$,
  'P0001', 'code_invalid', 'referral loop rejected');
reset role;
update public.profiles set created_at = now() - interval '8 days' where id = 'a0000000-0000-0000-0000-0000000000a3';
set local role authenticated;
select set_config('request.jwt.claims', current_setting('t.x'), true);
select throws_ok($$select public.bind_referral('REFR0001')$$, 'P0001', 'code_invalid', 'older than 7 days rejected');
reset role;

-- ---- referral money (150k: nothing; 300k with 20k commission: min(30k, 30% x 20k) held 30d; reversal voids)
select public.create_click('a0000000-0000-0000-0000-0000000000a2', 'shopee', 'https://shopee.vn/p', 'https://shopee.vn/p', null, 'app', null);
create temp table clk as select id, utm_content u from public.clicks where user_id = 'a0000000-0000-0000-0000-0000000000a2';
select public.ingest_at_transactions('t', (select jsonb_build_array(jsonb_build_object('conversion_id', 700001, 'merchant', 'shopee',
  'status', 1, 'is_confirmed', 1, 'transaction_id', 'R1', 'utm_content', u, 'commission', 10000, 'transaction_value', 150000,
  'update_time', now())) from clk));
select is((select status::text from public.referrals where referee_id = 'a0000000-0000-0000-0000-0000000000a2'), 'pending', '150k order: not qualified');
select is((select count(*)::int from public.wallet_ledger where entry_type = 'referral_bonus'), 0, '150k order: no bonus');
select public.ingest_at_transactions('t', (select jsonb_build_array(jsonb_build_object('conversion_id', 700002, 'merchant', 'shopee',
  'status', 1, 'is_confirmed', 1, 'transaction_id', 'R2', 'utm_content', u, 'commission', 20000, 'transaction_value', 300000,
  'update_time', now())) from clk));
select results_eq($$select status::text, bonus_vnd from public.referrals where referee_id = 'a0000000-0000-0000-0000-0000000000a2'$$,
  $$values ('rewarded'::text, 6000::bigint)$$, '300k/20k order: rewarded 30% of commission (cap 30k)');
select results_eq($$select amount_vnd, available_at > now() + interval '29 days' from public.wallet_ledger where entry_type = 'referral_bonus'$$,
  $$values (6000::bigint, true)$$, 'bonus held 30 days');
select is((select held_vnd from public.wallets where user_id = 'a0000000-0000-0000-0000-0000000000a1'), 6000::bigint, 'referrer held balance');
select public.ingest_at_transactions('t', (select jsonb_build_array(jsonb_build_object('conversion_id', 700002, 'merchant', 'shopee',
  'status', 2, 'is_confirmed', 0, 'transaction_id', 'R2', 'utm_content', u, 'commission', 20000, 'transaction_value', 300000,
  'update_time', now() + interval '1 minute')) from clk));
select is((select count(*)::int from public.wallet_ledger where entry_type = 'referral_reversal'), 1, 'reversed order -> referral_reversal');
select is((select status::text from public.referrals where referee_id = 'a0000000-0000-0000-0000-0000000000a2'), 'void', 'referral void');

-- ---- as E: activity, onboarding, profile
set local role authenticated;
select set_config('request.jwt.claims', current_setting('t.e'), true);
select lives_ok($$select public.touch_activity(); select public.touch_activity()$$, 'touch_activity idempotent');
select is((select count(*)::int from public.user_activity_days), 1, 'one activity row per day');
select lives_ok($$select public.complete_onboarding()$$, 'complete_onboarding');
select ok((select onboarded_at is not null from public.profiles where id = auth.uid()), 'onboarded_at set');
select throws_ok($$select public.update_profile('  ', null)$$, 'P0001', 'invalid_input', 'blank name rejected');
select throws_ok($$select public.update_profile(null, '{"foo":true}')$$, 'P0001', 'invalid_input', 'unknown pref key rejected');
select throws_ok($$select public.update_profile(null, '{"promo":"yes"}')$$, 'P0001', 'invalid_input', 'non-boolean pref rejected');
select lives_ok($$select public.update_profile(' Lan ', '{"promo":false}')$$, 'valid profile update');
select results_eq($$select display_name, (notification_prefs ->> 'promo')::boolean, (notification_prefs ->> 'order')::boolean
  from public.profiles where id = auth.uid()$$, $$values ('Lan'::text, false, true)$$, 'prefs merged, name trimmed');

-- ---- daily check-in: 50 xu, idempotent, 7th day 500, locked account rejected
select results_eq($$select coins, streak from public.daily_checkin()$$, $$values (50, 1)$$, 'day 1: 50 xu streak 1');
select results_eq($$select coins, streak from public.daily_checkin()$$, $$values (50, 1)$$, 'same day replay is idempotent');
select is((select coin_balance from public.profiles where id = auth.uid()), 50::bigint, 'coins credited once');
reset role;
update public.coin_ledger set idempotency_key = 'old-checkin' where reason = 'checkin';
update public.daily_checkins set day = day - 1, streak = 6 where user_id = 'a0000000-0000-0000-0000-0000000000a2';
set local role authenticated;
select set_config('request.jwt.claims', current_setting('t.e'), true);
select results_eq($$select coins, streak from public.daily_checkin()$$, $$values (500, 7)$$, '7th consecutive day: 500 xu');
reset role;
update public.profiles set locked_at = now() where id = 'a0000000-0000-0000-0000-0000000000a2';
delete from public.daily_checkins where day = private.vn_today();
set local role authenticated;
select set_config('request.jwt.claims', current_setting('t.e'), true);
select throws_ok($$select * from public.daily_checkin()$$, 'P0001', 'account_locked', 'locked account: no check-in');
select throws_ok($$select public.claim_mission('share_1')$$, 'P0001', 'account_locked', 'locked account: no mission claim');
reset role;
update public.profiles set locked_at = null where id = 'a0000000-0000-0000-0000-0000000000a2';

-- ---- missions
set local role authenticated;
select set_config('request.jwt.claims', current_setting('t.e'), true);
select results_eq($$select code, progress, claimed from public.get_mission_progress() order by code$$,
  $$values ('invite_1'::text, 0, false), ('orders_2', 1, false), ('share_1', 0, false)$$, 'progress: 1 order (pending/credited) counted');
select throws_ok($$select public.claim_mission('share_1')$$, 'P0001', 'invalid_input', 'incomplete mission rejected');
select throws_ok($$select public.claim_mission('invite_1')$$, 'P0001', 'invalid_input', 'invite mission is display only');
select throws_ok($$select public.claim_mission('nope')$$, 'P0001', 'invalid_input', 'unknown mission');
select throws_ok($$select public.record_link_share(999999999)$$, 'P0001', 'invalid_input', 'share of foreign/unknown click rejected');
select lives_ok($$select public.record_link_share((select id from public.clicks where user_id = auth.uid() limit 1))$$, 'record own link share');
select is(public.claim_mission('share_1'), 200, 'claim coins mission');
select throws_ok($$select public.claim_mission('share_1')$$, 'P0001', 'invalid_input', 'double claim rejected');
reset role;

-- second order this week -> vnd mission, held 30d
select public.ingest_at_transactions('t', (select jsonb_build_array(jsonb_build_object('conversion_id', 700003, 'merchant', 'shopee',
  'status', 0, 'is_confirmed', 0, 'transaction_id', 'R3', 'utm_content', u, 'commission', 1000, 'transaction_value', 50000,
  'transaction_time', now(), 'update_time', now())) from clk));
set local role authenticated;
select set_config('request.jwt.claims', current_setting('t.e'), true);
select is(public.claim_mission('orders_2'), 10000, 'claim vnd mission');
select is((select count(*)::int from public.wallet_ledger where entry_type = 'mission_bonus' and available_at > now() + interval '29 days'),
  1, 'mission_bonus posted held');

-- ---- notifications
reset role;
select private.notify('a0000000-0000-0000-0000-0000000000a2', 'system', 't1', null);
set local role authenticated;
select set_config('request.jwt.claims', current_setting('t.e'), true);
select cmp_ok(public.mark_notifications_read(null), '>=', 1, 'mark all read returns count');
select is(public.mark_notifications_read(null), 0, 'second call marks nothing');
reset role;

select * from finish();
rollback;
