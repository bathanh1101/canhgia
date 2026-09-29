-- Production reference data (idempotent). Source: docs/accesstrade-capability-matrix.md (spike 2026-09-29).
-- Commission bps are CONFIG (commission_policies endpoint 404s): sample values from campaign T&C text, admin/03 sync overrides.
insert into public.merchants (id, name, badge_letter, domains, at_campaign_id, link_api, datafeed_enabled, extension_enabled,
  activation_hours, hold_days, is_active, sort) values
  ('shopee', 'Shopee', 'S', '{shopee.vn}', '4751584435713464237', 'product_link', true, true, 168, 30, true, 1),
  ('lazada', 'Lazada', 'L', '{lazada.vn}', '5249638763776692551', 'product_link', false, true, 168, 30, true, 2),
  ('tiktok_shop', 'TikTok Shop', 'T', '{tiktok.com,shop.tiktok.com,vt.tiktok.com}', '6648523843406889655', 'tiktok_shop', false, true, 336, 30, true, 3),
  ('tiki', 'Tiki', 'T', '{tiki.vn}', '6023573823797709038', 'product_link', true, true, 168, 45, true, 4),
  ('agoda', 'Agoda', 'A', '{agoda.com}', '6817930100651517825', 'campaign_default', false, false, 24, 30, false, 5),
  ('traveloka', 'Traveloka', 'T', '{traveloka.com}', '6654251588167732819', 'campaign_default', false, false, 336, 30, true, 6),
  ('klook', 'Klook', 'K', '{klook.com}', '4704521809526929067', 'campaign_default', false, false, 720, 30, true, 7)
on conflict (id) do update set name = excluded.name, badge_letter = excluded.badge_letter, domains = excluded.domains,
  at_campaign_id = excluded.at_campaign_id, link_api = excluded.link_api, datafeed_enabled = excluded.datafeed_enabled,
  extension_enabled = excluded.extension_enabled, activation_hours = excluded.activation_hours, hold_days = excluded.hold_days,
  is_active = excluded.is_active, sort = excluded.sort;

-- category '' = merchant default; do nothing on conflict so admin/03 edits survive a re-run
insert into public.campaign_commissions (merchant_id, category_key, commission_rate_bps) values
  ('shopee', '', 180), ('lazada', '', 350), ('tiktok_shop', '', 1500), ('tiki', '', 420),
  ('agoda', '', 420), ('traveloka', '', 315), ('klook', '', 350)
on conflict (merchant_id, category_key) do nothing;

insert into public.vip_tiers (code, name, min_gmv_12m_vnd, bonus_bps) values
  ('dong', 'Đồng', 0, 0), ('bac', 'Bạc', 2000000, 500), ('vang', 'Vàng', 10000000, 1000), ('kim_cuong', 'Kim Cương', 30000000, 2000)
on conflict (code) do update set name = excluded.name;

-- global default: user gets 70% of commission (+ up to 20% VIP => <= 90%)
insert into public.cashback_rules (merchant_id, category_key, user_share_bps) values (null, null, 7000)
on conflict (merchant_id, category_key) do nothing;

insert into public.missions (code, title, kind, target, reward_kind, reward_amount, sort) values
  ('orders_2', 'Mua 2 đơn trong tuần', 'orders_in_week', 2, 'vnd', 10000, 1),
  ('share_1', 'Chia sẻ 1 link hoàn tiền', 'share_link', 1, 'coins', 200, 2),
  ('invite_1', 'Mời 1 bạn đăng ký', 'invite_signup', 1, 'vnd', 30000, 3)
on conflict (code) do update set title = excluded.title, kind = excluded.kind, target = excluded.target,
  reward_kind = excluded.reward_kind, reward_amount = excluded.reward_amount, sort = excluded.sort;

-- NAPAS BINs; e-wallets listed but disabled (no bank-account payout to a wallet)
insert into public.banks (bin, code, name, is_enabled, sort) values
  ('970436', 'VCB', 'Vietcombank', true, 1), ('970415', 'CTG', 'VietinBank', true, 2), ('970418', 'BIDV', 'BIDV', true, 3),
  ('970405', 'AGR', 'Agribank', true, 4), ('970407', 'TCB', 'Techcombank', true, 5), ('970422', 'MBB', 'MB Bank', true, 6),
  ('970416', 'ACB', 'ACB', true, 7), ('970432', 'VPB', 'VPBank', true, 8), ('970423', 'TPB', 'TPBank', true, 9),
  ('970403', 'STB', 'Sacombank', true, 10), ('970437', 'HDB', 'HDBank', true, 11), ('970441', 'VIB', 'VIB', true, 12),
  ('970443', 'SHB', 'SHB', true, 13), ('970448', 'OCB', 'OCB', true, 14), ('970426', 'MSB', 'MSB', true, 15),
  ('970431', 'EIB', 'Eximbank', true, 16), ('970440', 'SEAB', 'SeABank', true, 17), ('970454', 'VCCB', 'Viet Capital Bank', true, 18),
  ('970429', 'SCB', 'SCB', true, 19), ('970452', 'KLB', 'KienlongBank', true, 20),
  ('971025', 'MOMO', 'Ví MoMo', false, 90), ('971011', 'ZALOPAY', 'ZaloPay', false, 91)
on conflict (bin) do update set code = excluded.code, name = excluded.name, is_enabled = excluded.is_enabled, sort = excluded.sort;

-- patterns run on offers.name_norm (lower-case, no accents); the single capture is the model
insert into public.product_key_rules (brand, pattern, priority) values
  ('sony', '\ysony (wh ?-? ?[0-9]{3,4}[a-z]*[0-9]*)', 10),
  ('sony', '\ysony (wf ?-? ?[0-9]{3,4}[a-z]*[0-9]*)', 10),
  ('apple', '\y(iphone [0-9]{1,2}(?: pro max| pro| plus| mini| max)?(?: [0-9]{2,4} ?(?:gb|tb))?)\y', 20),
  ('apple', '\y(airpods (?:pro|max)?(?: ?[0-9])?(?: gen ?[0-9])?)\y', 20),
  ('apple', '\y(macbook (?:air|pro) ?[0-9]{0,2}(?: m[0-9])?)\y', 20),
  ('samsung', '\y(galaxy s[0-9]{2}(?: ultra| plus| fe)?(?: [0-9]{2,4} ?(?:gb|tb))?)\y', 30),
  ('samsung', '\y(galaxy z (?:flip|fold) ?[0-9]+)\y', 30),
  ('xiaomi', '\y(redmi (?:note )?[0-9]{1,2}[a-z]*(?: pro| plus)?(?: [0-9]{1,3} ?(?:gb|tb))?)\y', 40),
  ('xiaomi', '\y(poco [a-z][0-9]{1,2}[a-z]*(?: pro)?)\y', 40)
on conflict (brand, pattern) do nothing;
