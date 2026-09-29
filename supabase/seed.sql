-- LOCAL DEV ONLY. Never `db push --include-seed`. Production reference data lives in migration 20261001002000.

-- Vault secrets the migrations reference but never create (dev values)
select vault.create_secret('dev-cccd-pepper-not-secret', 'cccd_pepper')
 where not exists (select 1 from vault.secrets where name = 'cccd_pepper');
select vault.create_secret('http://kong:8000', 'project_url')
 where not exists (select 1 from vault.secrets where name = 'project_url');
select vault.create_secret('dev-cron-secret', 'cron_secret')
 where not exists (select 1 from vault.secrets where name = 'cron_secret');

-- users (profiles + wallets via trigger): 1 admin, 2 shoppers
-- aud/role/email_confirmed_at/identities are what GoTrue needs to find these users for OTP + generate_link;
-- token columns are '' (not NULL) because GoTrue scans them into non-nullable strings.
insert into auth.users (id, instance_id, aud, role, email, email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  confirmation_token, recovery_token, email_change_token_new, email_change, email_change_token_current, phone_change,
  phone_change_token, reauthentication_token, created_at, updated_at) values
  ('11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'admin@test.canhgia.local', now(),
   '{"provider":"email","providers":["email"]}', '{"full_name":"Admin Test"}', '', '', '', '', '', '', '', '', now(), now()),
  ('22222222-2222-2222-2222-222222222222', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'minh@test.canhgia.local', now(),
   '{"provider":"email","providers":["email"]}', '{"full_name":"Minh Nguyen"}', '', '', '', '', '', '', '', '', now(), now()),
  ('33333333-3333-3333-3333-333333333333', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'lan@test.canhgia.local', now(),
   '{"provider":"email","providers":["email"]}', '{"full_name":"Lan Tran"}', '', '', '', '', '', '', '', '', now(), now());
insert into auth.identities (id, user_id, provider_id, provider, identity_data, created_at, updated_at)
select gen_random_uuid(), u.id, u.id::text, 'email',
       jsonb_build_object('sub', u.id::text, 'email', u.email, 'email_verified', true), now(), now()
  from auth.users u where u.id in ('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', '33333333-3333-3333-3333-333333333333');
insert into public.admins (user_id) values ('11111111-1111-1111-1111-111111111111');
update public.profiles set vip_tier_code = 'dong' where id in ('22222222-2222-2222-2222-222222222222', '33333333-3333-3333-3333-333333333333');
update public.profiles set vip_tier_code = 'bac' where id = '22222222-2222-2222-2222-222222222222';

-- offers: two merchants sell the same Sony XM5, plus near-misses and an unmatched title
select public.upsert_offers('shopee', '[
  {"external_product_id":"sp-1","name":"Tai nghe Sony WH-1000XM5 Đen chính hãng","brand":"Sony","price":7490000,"list_price":8990000,"shop_name":"Sony Official Mall","url":"https://shopee.vn/sp-1","cashback_eligible":true},
  {"external_product_id":"sp-2","name":"Tai nghe Sony WH-1000XM4 Bạc","brand":"Sony","price":5290000,"shop_name":"Sony Official Mall","url":"https://shopee.vn/sp-2"},
  {"external_product_id":"sp-3","name":"iPhone 15 Pro 256GB Titan","brand":"Apple","price":26990000,"shop_name":"Apple Mall","url":"https://shopee.vn/sp-3"},
  {"external_product_id":"sp-4","name":"Ốp lưng silicon trong suốt","price":39000,"shop_name":"Phụ kiện 24h","url":"https://shopee.vn/sp-4"}
]');
select public.upsert_offers('tiki', '[
  {"external_product_id":"tk-1","name":"Tai nghe chụp tai Sony WH-1000XM5 - Đen","brand":"Sony","price":7390000,"list_price":8990000,"shop_name":"Tiki Trading","url":"https://tiki.vn/tk-1"},
  {"external_product_id":"tk-2","name":"iPhone 15 128GB Hồng","brand":"Apple","price":19490000,"shop_name":"Tiki Trading","url":"https://tiki.vn/tk-2"}
]');
select public.assign_product_groups();
insert into public.price_snapshots (offer_id, day, price)
select o.id, current_date - d, o.price + (d * 10000)
  from public.offers o cross join generate_series(1, 6) d
on conflict do nothing;

insert into public.vouchers (merchant_id, external_id, code, title, discount_text, url, ends_at) values
  ('shopee', 'v1', 'CANHGIA50', 'Giảm 50K đơn từ 500K', '50.000đ', 'https://shopee.vn/voucher/1', now() + interval '10 days'),
  ('tiki', 'v2', null, 'Freeship mọi đơn', 'Freeship', 'https://tiki.vn/voucher/2', now() + interval '5 days');

-- orders across states through the real ingest path
do $$
declare
  c1 record;
  c2 record;
begin
  select * into c1 from public.create_click('22222222-2222-2222-2222-222222222222', 'shopee', 'https://shopee.vn/sp-1', 'https://shopee.vn/sp-1', null, 'app', null);
  select * into c2 from public.create_click('33333333-3333-3333-3333-333333333333', 'tiki', 'https://tiki.vn/tk-1', 'https://tiki.vn/tk-1', null, 'app', null);
  perform public.ingest_at_transactions('seed', jsonb_build_array(
    jsonb_build_object('conversion_id', 900001, 'merchant', 'shopee', 'status', 0, 'is_confirmed', 0, 'transaction_id', 'SP0001',
      'utm_content', c1.utm_content, 'commission', 150000, 'transaction_value', 7490000, 'transaction_time', now() - interval '2 days',
      'update_time', now()),
    jsonb_build_object('conversion_id', 900002, 'merchant', 'shopee', 'status', 1, 'is_confirmed', 1, 'transaction_id', 'SP0002',
      'utm_content', c1.utm_content, 'commission', 40000, 'transaction_value', 900000, 'transaction_time', now() - interval '40 days',
      'update_time', now()),
    jsonb_build_object('conversion_id', 900003, 'merchant', 'tiki', 'status', 2, 'is_confirmed', 0, 'transaction_id', 'TK0001',
      'utm_content', c2.utm_content, 'commission', 30000, 'transaction_value', 700000, 'transaction_time', now() - interval '10 days',
      'update_time', now()),
    jsonb_build_object('conversion_id', 900004, 'merchant', 'tiki', 'status', 0, 'is_confirmed', 0, 'transaction_id', 'TK0002',
      'commission', 20000, 'transaction_value', 500000, 'transaction_time', now() - interval '1 day', 'update_time', now())));
end $$;

-- a watch item and some activity days
insert into public.watchlist_items (user_id, product_group_id, target_price_vnd)
select '22222222-2222-2222-2222-222222222222', product_group_id, 7000000 from public.offers where external_product_id = 'sp-1';
insert into public.user_activity_days (user_id, day)
select '22222222-2222-2222-2222-222222222222', current_date - d from generate_series(0, 4) d;
