begin;
create extension if not exists pgtap with schema extensions;
grant execute on all functions in schema extensions to public;
select plan(26);

insert into public.merchants (id, name, at_campaign_id) values ('shopee', 'Shopee', 'shopee')
  on conflict (id) do update set name = excluded.name, at_campaign_id = excluded.at_campaign_id;
insert into auth.users (id, email) values ('a0000000-0000-0000-0000-00000000000a', 'a@x.io'), ('b0000000-0000-0000-0000-00000000000b', 'b@x.io');
select set_config('t.a', '{"sub":"a0000000-0000-0000-0000-00000000000a","role":"authenticated","aal":"aal1"}', true);
select case when exists (select 1 from vault.secrets where name = 'cccd_pepper') then null
  else vault.create_secret('test-pepper', 'cccd_pepper') end;
insert into storage.objects (bucket_id, name, owner) values
  ('kyc', 'a0000000-0000-0000-0000-00000000000a/front.jpg', 'a0000000-0000-0000-0000-00000000000a'),
  ('kyc', 'a0000000-0000-0000-0000-00000000000a/back.jpg', 'a0000000-0000-0000-0000-00000000000a');

-- devices: second new device -> 24h hold
set local role authenticated;
select set_config('request.jwt.claims', current_setting('t.a'), true);
select public.register_device('device-one-id', 'android', 'Pixel');
reset role;
select ok((select withdrawal_hold_until is null from public.profiles where id = 'a0000000-0000-0000-0000-00000000000a'), 'first device: no hold');
set local role authenticated;
select set_config('request.jwt.claims', current_setting('t.a'), true);
select public.register_device('device-one-id', 'android', 'Pixel');
select public.register_device('device-two-id', 'ios', 'iPhone');
select throws_ok($$select public.register_device('x', 'ios', null)$$, 'P0001', 'invalid_input', 'short device id rejected');
reset role;
select is((select count(*)::int from public.user_devices where user_id = 'a0000000-0000-0000-0000-00000000000a'), 2, 'two devices, re-register is idempotent');
select ok((select withdrawal_hold_until > now() + interval '23 hours' from public.profiles where id = 'a0000000-0000-0000-0000-00000000000a'), 'new device -> 24h hold');

-- KYC + bank
set local role authenticated;
select set_config('request.jwt.claims', current_setting('t.a'), true);
select throws_ok($$select public.add_bank_account('970436', '0123456789', 'Nguyen Van A')$$, 'P0001', 'kyc_required', 'bank before KYC -> kyc_required');
select throws_ok($$select public.submit_kyc('Nguyen Van A', '012345678901', 'b0000000-0000-0000-0000-00000000000b/front.jpg', 'a0000000-0000-0000-0000-00000000000a/back.jpg')$$,
  'P0001', 'invalid_input', 'path outside own prefix');
select throws_ok($$select public.submit_kyc('Nguyen Van A', '012345678901', 'a0000000-0000-0000-0000-00000000000a/none.jpg', 'a0000000-0000-0000-0000-00000000000a/back.jpg')$$,
  'P0001', 'invalid_input', 'missing storage object');
select throws_ok($$select public.submit_kyc('Nguyen Van A', '12345', 'a0000000-0000-0000-0000-00000000000a/front.jpg', 'a0000000-0000-0000-0000-00000000000a/back.jpg')$$,
  'P0001', 'invalid_input', 'bad id number');
select is(public.submit_kyc('Nguyễn Văn A', '012345678901', 'a0000000-0000-0000-0000-00000000000a/front.jpg', 'a0000000-0000-0000-0000-00000000000a/back.jpg'),
  'pending'::public.kyc_status, 'submit_kyc -> pending');
reset role;
select results_eq($$select id_number_last4, id_number_hmac <> '012345678901', length(id_number_hmac) from public.kyc_profiles$$, $$values ('8901', true, 64)$$, 'CCCD stored as last4 + hmac');
update public.kyc_profiles set status = 'verified';
set local role authenticated;
select set_config('request.jwt.claims', current_setting('t.a'), true);
select throws_ok($$select public.add_bank_account('970436', '0123456789', 'Tran Thi B')$$, 'P0001', 'invalid_input', 'holder name must match CCCD');
select set_config('t.bank', public.add_bank_account('970436', '0123456789', 'NGUYEN VAN A')::text, true);
select is(public.add_bank_account('970436', '0123456789', 'NGUYEN VAN A')::text, current_setting('t.bank'), 'same account returns same id');
reset role;
select ok((select is_default and not holder_name_verified from public.bank_accounts where id = current_setting('t.bank')::uuid), 'first account default, unverified');

-- clicks: dedupe, limit, failed excluded
select set_config('t.utm', (select utm_content from public.create_click('a0000000-0000-0000-0000-00000000000a', 'shopee', 'o', 'https://s/1', null, 'app', null)), true);
select ok(current_setting('t.utm') ~ '^u\d+c\d+$', 'click utm_content');
select public.set_click_link((select id from public.clicks where user_id = 'a0000000-0000-0000-0000-00000000000a' order by id limit 1), 'https://aff/1', 'https://s.cg/1');
select results_eq($$select aff_link from public.create_click('a0000000-0000-0000-0000-00000000000a', 'shopee', 'o', 'https://s/1', null, 'app', null)$$,
  $$values ('https://aff/1')$$, 'dedupe hit returns existing aff_link');
select is((select count(*)::int from public.clicks where user_id = 'a0000000-0000-0000-0000-00000000000a'), 1, 'dedupe creates no new click');
update public.app_settings set value = '2' where key = 'click_limit_per_hour';
select public.create_click('a0000000-0000-0000-0000-00000000000a', 'shopee', 'o', 'https://s/2', null, 'app', null);
select throws_ok($$select * from public.create_click('a0000000-0000-0000-0000-00000000000a', 'shopee', 'o', 'https://s/3', null, 'app', null)$$, 'P0001', 'rate_limited', 'hourly click limit');
select public.set_click_link((select max(id) from public.clicks where user_id = 'a0000000-0000-0000-0000-00000000000a'), null, null);
select lives_ok($$select * from public.create_click('a0000000-0000-0000-0000-00000000000a', 'shopee', 'o', 'https://s/3', null, 'app', null)$$, 'failed clicks do not count toward the limit');

-- AT rate bucket, sync lock
select is((select count(*) filter (where public.at_rate_limit_take(1)) from generate_series(1, 12)), 5::bigint, 'bucket allows capacity then refuses');
select is(public.sync_lock('sync-transactions', 60), true, 'lock acquired');
select is(public.sync_lock('sync-transactions', 60), false, 'second lock refused');
select public.sync_save('sync-transactions', '{"page":3}');
select public.sync_finish('sync-transactions', true, null, '2026-09-01T00:00:00Z');
select results_eq($$select cursor is null, last_success_at = '2026-09-01T00:00:00Z'::timestamptz, locked_until is null from public.sync_state where job = 'sync-transactions'$$,
  $$values (true, true, true)$$, 'finish(success) resets cursor, sets watermark, unlocks');

-- push outbox: prefs respected, tokens attached
update public.profiles set notification_prefs = notification_prefs || '{"promo":false}' where id = 'a0000000-0000-0000-0000-00000000000a';
insert into public.push_tokens (token, user_id, platform) values ('tok1', 'a0000000-0000-0000-0000-00000000000a', 'android');
insert into public.notifications (user_id, type, title) values ('a0000000-0000-0000-0000-00000000000a', 'promo', 'skip'), ('a0000000-0000-0000-0000-00000000000a', 'wallet', 'send');
select results_eq($$select title, tokens from public.claim_push_batch(1000) where user_id = 'a0000000-0000-0000-0000-00000000000a'$$, $$values ('send', array['tok1'])$$, 'claim skips disabled types, attaches tokens');
select is((select count(*)::int from public.claim_push_batch(1000) where user_id = 'a0000000-0000-0000-0000-00000000000a'), 0, 'claimed rows are not re-claimed within 10 minutes');

-- catalog upsert: one bad row does not block the page
select results_eq($$select upserted, snapshots from public.upsert_offers('shopee', '[
  {"external_product_id":"p1","name":"Áo thun","price":100000,"sku":"S1","brand":"B"},
  {"external_product_id":"p2","price":5},
  {"external_product_id":"p3","name":"Quần","price":200000,"sku":"S1","brand":"B"}]')$$, $$values (2, 2)$$, 'upsert_offers: 2 ok, 1 skipped');
select is((select count(distinct product_group_id)::int from public.offers where external_product_id in ('p1', 'p3')), 1, 'same brand+sku -> one product group');

select * from finish();
rollback;
