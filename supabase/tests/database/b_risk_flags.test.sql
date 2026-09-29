begin;
create extension if not exists pgtap with schema extensions;
grant execute on all functions in schema extensions to public;
select plan(21);

create function pg_temp.u(i int) returns uuid language sql as $$ select ('a0000000-0000-0000-0000-0000000001' || lpad(i::text, 2, '0'))::uuid $$;
delete from public.fraud_flags;
delete from public.user_risk;
insert into auth.users (id, email) select pg_temp.u(i), 'r' || i || '@x.io' from generate_series(1, 13) i;
update public.profiles set created_at = now() - (100 - id_rank) * interval '1 hour'
  from (select id, row_number() over (order by email) id_rank from public.profiles where email like 'r%@x.io') r where profiles.id = r.id;

-- 1,2 share dev-1 | 3,4 share id H | 5,6 share bank | 7 clicks | 8 referred 9 (share dev-2) | 10 dev-3 + id H2 + bank vs 11,12,13
insert into public.user_devices (user_id, device_hash, platform) values
  (pg_temp.u(1), 'dev-1', 'android'), (pg_temp.u(2), 'dev-1', 'android'),
  (pg_temp.u(8), 'dev-2', 'android'), (pg_temp.u(9), 'dev-2', 'ios'),
  (pg_temp.u(10), 'dev-3', 'android'), (pg_temp.u(11), 'dev-3', 'android'), (pg_temp.u(13), 'dev-solo', 'android');
insert into public.kyc_profiles (user_id, full_name, full_name_norm, id_number_last4, id_number_hmac, front_path, back_path)
select pg_temp.u(i), 'n', 'n', '1234', h, 'f', 'b' from (values (3, 'H'), (4, 'H'), (10, 'H2'), (12, 'H2')) v(i, h);
insert into public.bank_accounts (user_id, bank_bin, account_number, account_name, account_name_norm)
select pg_temp.u(i), '970436', a, 'n', 'n' from (values (5, '111111'), (6, '111111'), (10, '222222'), (13, '222222')) v(i, a);
insert into public.clicks (user_id, merchant_id, status)
select pg_temp.u(7), 'shopee', 'ok' from generate_series(1, 51);
insert into public.clicks (user_id, merchant_id, status)
select pg_temp.u(13), 'shopee', 'ok' from generate_series(1, 50);
update public.referrals set referrer_id = pg_temp.u(8) where referee_id = pg_temp.u(9);
insert into public.referrals (referrer_id, referee_id) select pg_temp.u(8), pg_temp.u(9) where not exists (select 1 from public.referrals where referee_id = pg_temp.u(9));

select is(public.refresh_risk_scores(), 9, 'first run inserts every distinct signal once');
select is((select count(*)::int from public.fraud_flags where type = 'multi_account_device' and status = 'open'), 3, 'one open multi_account_device flag per shared device');
select is((select count(*)::int from public.fraud_flags where type = 'multi_account_device' and dedupe_key = 'mad:dev-1'), 1, 'dedupe key mad:<device_hash>');
select is((select count(*)::int from public.fraud_flags where type = 'shared_identity'), 2, 'shared_identity per id hmac');
select is((select count(*)::int from public.fraud_flags where dedupe_key = 'sba:970436:111111'), 1, 'shared bank flag key');
select is((select count(*)::int from public.fraud_flags where type = 'abnormal_clicks'), 1, '> 50 ok clicks: 51 flags, 50 does not');
select is((select count(*)::int from public.fraud_flags where dedupe_key = 'srf:' || (select id from public.referrals where referee_id = pg_temp.u(9))), 1, 'referrer/referee sharing a device -> self_referral flag');
select is(public.refresh_risk_scores(), 0, 're-run inserts nothing');
select is((select count(*)::int from public.fraud_flags where type = 'multi_account_device' and status = 'open'), 3, 're-run: still one open flag per device');

select results_eq($$select user_id, risk_score, level from public.user_risk where user_id in (pg_temp.u(1), pg_temp.u(3), pg_temp.u(5), pg_temp.u(7), pg_temp.u(9), pg_temp.u(10)) order by user_id$$,
  $$values (pg_temp.u(1), 40, 'medium'::text), (pg_temp.u(3), 60, 'high'), (pg_temp.u(5), 50, 'medium'), (pg_temp.u(7), 20, 'low'),
           (pg_temp.u(9), 90, 'high'), (pg_temp.u(10), 100, 'high')$$, 'weights, levels (<30 low, <60 medium, else high) and cap 100');
select is((select count(*)::int from public.user_risk where user_id = pg_temp.u(13)), 1, 'user with a shared bank gets a row');
select is((select risk_score from public.user_risk where user_id = pg_temp.u(13)), 50, '50 clicks (not > 50) adds nothing');

-- signal disappears -> score resets, flag stays for the admin to close
delete from public.user_devices where user_id = pg_temp.u(2);
select is(public.refresh_risk_scores(), 0, 'no new flags');
select results_eq($$select risk_score, level from public.user_risk where user_id = pg_temp.u(1)$$, $$values (0, 'low'::text)$$, 'stale score reset to 0');
select is((select status::text from public.fraud_flags where dedupe_key = 'mad:dev-1'), 'open', 'flag kept open');
-- admin dismissed flag is not re-opened or duplicated
update public.fraud_flags set status = 'dismissed' where dedupe_key = 'mad:dev-2';
select is(public.refresh_risk_scores(), 0, 'dismissed flag is not re-inserted');
select is((select status::text from public.fraud_flags where dedupe_key = 'mad:dev-2'), 'dismissed', 'dismissed stays dismissed');

-- privileges: service only
set local role authenticated;
select throws_ok($$select public.refresh_risk_scores()$$, '42501', null, 'authenticated cannot run risk job');
select throws_ok($$select public.refresh_vip_tiers()$$, '42501', null, 'authenticated cannot run VIP job');
reset role;
set local role service_role;
select lives_ok($$select public.refresh_risk_scores(); select public.assign_product_groups(); select public.evaluate_price_alerts(); select public.refresh_vip_tiers()$$,
  'service_role runs every job');
reset role;
select is((select count(*)::int from public.fraud_flags), 9, 'nine flags in total');

select * from finish();
rollback;
