begin;
create extension if not exists pgtap with schema extensions;
grant execute on all functions in schema extensions to public;
select plan(49);

-- hermetic: drop dev seed catalog rows
delete from public.watchlist_items;
delete from public.offers;
delete from public.product_groups;

select public.upsert_offers('shopee', '[
  {"external_product_id":"s1","name":"Tai nghe Sony WH-1000XM5 Đen","brand":"Sony","price":7490000,"list_price":8990000,"shop_name":"Sony Official Mall"},
  {"external_product_id":"s2","name":"Tai nghe Sony WH-1000XM4 Bạc","brand":"Sony","price":5290000,"shop_name":"Shop A"},
  {"external_product_id":"s3","name":"iPhone 15 Pro 256GB Titan","brand":"Apple","price":26990000,"shop_name":"Shop A"},
  {"external_product_id":"s4","name":"Ốp lưng silicon trong suốt","sku":"123","price":39000,"shop_name":"Shop A"},
  {"external_product_id":"s5","name":"Sách Nhà giả kim","sku":"8934974123456","price":60000,"shop_name":"Shop B"},
  {"external_product_id":"s6","name":"Bút bi Thiên Long","price":1000000,"shop_name":"Shop B"}
]');
select public.upsert_offers('tiki', '[
  {"external_product_id":"t1","name":"Tai nghe chụp tai Sony WH 1000XM5 - Bạc","brand":"Sony","price":7390000,"shop_name":"Tiki Trading"},
  {"external_product_id":"t2","name":"iPhone 15 128GB Hồng","brand":"Apple","price":19490000,"shop_name":"Tiki Trading"},
  {"external_product_id":"t3","name":"Nhà giả kim - Paulo Coelho","sku":"8934974123456","price":55000,"shop_name":"Tiki Trading"}
]');
select ok(public.assign_product_groups() >= 6, 'assign_product_groups touches offers');
create temp table g as select external_product_id e, product_group_id gid from public.offers;
grant select on g to public;
select is((select count(distinct gid)::int from g where e in ('s1', 't1')), 1, 'XM5 on two merchants share one group');
select isnt((select gid from g where e = 's1'), (select gid from g where e = 's2'), 'XM4 is a different group');
select isnt((select gid from g where e = 's3'), (select gid from g where e = 't2'), 'iPhone 15 Pro 256GB vs iPhone 15 128GB differ');
select ok((select gid is null from g where e = 's4'), 'unmatched title with non-GTIN sku -> no group');
select ok((select gid is null from g where e = 's6'), 'unmatched title without sku -> no group');
select is((select count(distinct gid)::int from g where e in ('s5', 't3')), 1, 'GTIN sku groups across merchants');
select is((select group_key from public.product_groups where id = (select gid from g where e = 's1')), 'sony wh1000xm5', 'group key = brand + normalised model');
select is(public.assign_product_groups(), 0, 'grouping is idempotent');
select is((select count(*)::int from public.product_groups), 5, 'no orphan groups');

-- ---- search (anon)
insert into public.offers (merchant_id, external_product_id, name, name_norm, fts, price)
select 'shopee', 'bulk' || i, 'Quat mini ' || i, 'quat mini ' || i, to_tsvector('simple', 'quat mini ' || i), 1000 * i
  from generate_series(1, 60) i;
set local role anon;
select is((select count(*)::int from public.search_offers('quat mini', p_limit => 10000)), 50, 'p_limit clamped to 50');
select is((select count(*)::int from public.search_offers('quat mini', p_limit => 0)), 1, 'p_limit floor is 1');
select is((select count(*)::int from public.search_offers('quat mini', p_limit => 50, p_offset => 55)), 5, 'offset honoured');
select results_eq($$select external_product_id from public.offers o join public.search_offers('sony wh-1000xm5', p_sort => 'price_asc') s on s.offer_id = o.id order by s.price_vnd$$,
  $$values ('t1'::text), ('s1')$$, 'FTS finds both XM5 offers, price_asc order, hyphen/space variants');
select is((select count(*)::int from public.search_offers('SON tai ng')), 3, 'prefix + accent-insensitive + case-insensitive');
select is((select count(*)::int from public.search_offers('bạc')), 2, 'accented query matches');
select is((select count(*)::int from public.search_offers('   ')), 0, 'blank query -> empty');
select is((select count(*)::int from public.search_offers('sony', p_merchants => array['tiki'])), 1, 'merchant filter');
select is((select max(offers_in_group)::int from public.search_offers('wh 1000xm5')), 2, 'offers_in_group counted');
select throws_ok($$select * from public.search_offers('sony', p_sort => 'random')$$, 'P0001', 'invalid_input', 'bad sort rejected');
select is((select est_cashback_vnd from public.search_offers('but bi')), 12600::bigint, 'est cashback = 1.000.000 x 1,80% x 70%');
select is((select rate_bps from public.search_offers('but bi')), 126, 'rate_bps relative to price');
select is((select price_vnd from public.search_offers('quat mini', p_sort => 'price_desc', p_limit => 1)), 60000::bigint, 'price_desc');

-- ---- compare / history
select results_eq($$select merchant_id from public.get_compare((select gid from g where e = 's1'))$$,
  $$values ('tiki'::text), ('shopee')$$, 'compare sorted by effective price (price - cashback)');
select ok((select is_mall from public.get_compare((select gid from g where e = 's1')) where merchant_id = 'shopee'), 'Official Mall shop flagged');
select is((select count(*)::int from public.get_compare((select gid from g where e = 's2'))), 0, 'single-offer group -> no compare');
select is((select count(*)::int from public.get_compare(-1)), 0, 'unknown group -> empty');
reset role;
insert into public.price_snapshots (offer_id, day, price)
select o.id, current_date - d, o.price + d * 1000 from public.offers o, generate_series(1, 3) d
 where o.external_product_id in ('s1', 't1');
set local role anon;
select results_eq($$select day, min_price_vnd from public.get_price_history((select gid from g where e = 's1'), 2) order by day$$,
  $$values (current_date - 2, 7392000::bigint), (current_date - 1, 7391000::bigint), (current_date, 7390000::bigint)$$,
  'history = min price per day inside window (today snapshot from upsert)');
select cmp_ok((select count(*)::int from public.get_price_history((select gid from g where e = 's1'), 100000)), '<=', 366, 'days clamped');

-- ---- estimate_cashback / merchants / settings
select results_eq($$select commission_vnd, base_cashback_vnd, vip_bonus_vnd, user_cashback_vnd, app_keeps_vnd, base_rate_bps, vip_rate_bps
  from public.estimate_cashback('shopee', null, 1000000, 'vang')$$,
  $$values (18000::bigint, 12600::bigint, 1800::bigint, 14400::bigint, 3600::bigint, 126, 18)$$, 'VIP bonus is a share of commission');
select results_eq($$select user_cashback_vnd, vip_bonus_vnd from public.estimate_cashback('shopee', null, 1000000)$$,
  $$values (12600::bigint, 0::bigint)$$, 'anon: no VIP');
select throws_ok($$select * from public.estimate_cashback('agoda', null, 1000000)$$, 'P0001', 'invalid_input', 'inactive merchant rejected');
select throws_ok($$select * from public.estimate_cashback('shopee', null, 0)$$, 'P0001', 'invalid_input', 'zero value rejected');
select throws_ok($$select * from public.estimate_cashback('shopee', null, 1000, 'zzz')$$, 'P0001', 'invalid_input', 'unknown tier rejected');
select is((select count(*)::int from public.get_merchant_rates()), 6, 'active merchants only (Agoda is off)');
select results_eq($$select max_user_rate_bps, hold_days, activation_hours from public.get_merchant_rates() where merchant_id = 'tiki'$$,
  $$values (294, 45, 168)$$, 'Tiki: 420 bps x 70%, hold 45d, 7d cookie');
select results_eq($$select (s ->> 'min_withdraw_vnd')::int, (s ->> 'active_merchants')::int, (s ->> 'max_rate_bps')::int
  from (select public.get_public_settings() s) x$$, $$values (50000, 6, 1050)$$, 'public settings');
select ok(public.get_public_settings() ?& array['min_withdraw_vnd', 'withdraw_daily_cap_vnd', 'referral_bonus_vnd', 'withdraw_eta_text', 'landing_stats', 'max_rate_bps', 'active_merchants'],
  'public settings carry every contract key');
select throws_ok($$select * from public.assign_product_groups()$$, '42501', null, 'anon cannot run jobs');
reset role;

-- ---- price alerts (once / 24h)
insert into auth.users (id, email) values ('a0000000-0000-0000-0000-0000000000b1', 'w@x.io');
insert into public.watchlist_items (user_id, product_group_id, target_price_vnd) values
  ('a0000000-0000-0000-0000-0000000000b1', (select gid from g where e = 's1'), 7400000),
  ('a0000000-0000-0000-0000-0000000000b1', (select gid from g where e = 's2'), 5000000);
select is(public.evaluate_price_alerts(), 1, 'only the group at/below target notifies');
select is((select count(*)::int from public.notifications where user_id = 'a0000000-0000-0000-0000-0000000000b1' and type = 'promo'), 1, 'promo notification');
select is(public.evaluate_price_alerts(), 0, 'no repeat within 24h');
update public.watchlist_items set last_notified_at = now() - interval '25 hours';
select is(public.evaluate_price_alerts(), 1, 'repeats after 24h');

-- ---- VIP refresh: 12m credited GMV
insert into public.orders (source, merchant_id, transaction_id, user_id, value_vnd, credit_state, order_time) values
  ('manual', 'shopee', 'V1', 'a0000000-0000-0000-0000-0000000000b1', 11000000, 'credited', now() - interval '2 months'),
  ('manual', 'shopee', 'V2', 'a0000000-0000-0000-0000-0000000000b1', 50000000, 'credited', now() - interval '14 months');
select ok(public.refresh_vip_tiers() >= 1, 'refresh_vip_tiers changes profiles');
select is((select vip_tier_code from public.profiles where id = 'a0000000-0000-0000-0000-0000000000b1'), 'vang', '11M within 12m -> Vàng (old order ignored)');
select is(public.refresh_vip_tiers(), 0, 'idempotent');

-- ---- admin_update_vip_tier / cashback rule caps (see b_admin_reports for gate)
select is((select count(*)::int from public.vip_tiers), 4, 'four VIP tiers seeded');
select is((select array_agg(bonus_bps order by bonus_bps) from public.vip_tiers), array[0, 500, 1000, 2000], 'VIP bps 0/500/1000/2000');
select is((select user_share_bps from public.cashback_rules where merchant_id is null and category_key is null), 7000, 'default cashback rule 70%');

select * from finish();
rollback;
