-- Service jobs (called by cron / datafeed sync): grouping, price alerts, VIP tiers, risk scoring.

-- Exact-match grouping only: brand + normalised model from product_key_rules, else GTIN sku, else no group.
-- Overwrites offers.product_group_id (upsert_offers resets it), so run after every datafeed page/sync.
create function public.assign_product_groups() returns int
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare
  n int;
begin
  create temporary table if not exists pg_keys (id bigint primary key, k text) on commit drop;
  truncate pg_keys;
  insert into pg_keys
    select o.id, coalesce(
             (select extensions.unaccent(lower(r.brand || ' ' || regexp_replace((regexp_match(o.name_norm, r.pattern))[1], '[^a-z0-9]', '', 'g')))
                from public.product_key_rules r where o.name_norm ~ r.pattern
               order by r.priority, r.id limit 1),
             case when o.sku ~ '^\d{8,14}$' then 'gtin:' || o.sku end)
      from public.offers o;
  insert into public.product_groups (group_key) select distinct k from pg_keys where k is not null on conflict do nothing;
  update public.offers o set product_group_id = g.id
    from pg_keys k left join public.product_groups g on g.group_key = k.k
   where o.id = k.id and o.product_group_id is distinct from g.id;
  get diagnostics n = row_count;
  delete from public.product_groups g
   where not exists (select 1 from public.offers o where o.product_group_id = g.id)
     and not exists (select 1 from public.watchlist_items w where w.product_group_id = g.id);
  return n;
end $$;

-- at most one notification per watch item per 24h
create function public.evaluate_price_alerts() returns int
language plpgsql security definer set search_path = pg_catalog, public as $$
declare
  w record;
  n int := 0;
begin
  for w in
    select wi.id, wi.user_id, wi.product_group_id, wi.target_price_vnd, m.p
      from public.watchlist_items wi
      cross join lateral (select min(o.price) p from public.offers o
                           where o.product_group_id = wi.product_group_id and o.price is not null) m
     where m.p <= wi.target_price_vnd and (wi.last_notified_at is null or wi.last_notified_at < now() - interval '24 hours')
       and exists (select 1 from public.profiles p where p.id = wi.user_id and p.locked_at is null)
     for update of wi skip locked
  loop
    perform private.notify(w.user_id, 'promo', 'Giá đã giảm tới mức bạn muốn', 'Giá thấp nhất hiện tại: ' || w.p || 'đ',
      jsonb_build_object('product_group_id', w.product_group_id, 'price_vnd', w.p, 'watch_id', w.id));
    update public.watchlist_items set last_notified_at = now() where id = w.id;
    n := n + 1;
  end loop;
  return n;
end $$;

-- highest tier whose min_gmv_12m_vnd <= credited GMV of the last 12 months; returns profiles changed
create function public.refresh_vip_tiers() returns int
language plpgsql security definer set search_path = pg_catalog, public as $$
declare
  n int;
begin
  with g as (
    select p.id, coalesce((select sum(o.value_vnd) from public.orders o
                            where o.user_id = p.id and o.credit_state = 'credited'
                              and coalesce(o.order_time, o.created_at) > now() - interval '12 months'), 0) gmv
      from public.profiles p),
  t as (
    select g.id, (select x.code from public.vip_tiers x where x.min_gmv_12m_vnd <= g.gmv
                   order by x.min_gmv_12m_vnd desc limit 1) code from g)
  update public.profiles p set vip_tier_code = t.code from t
   where p.id = t.id and t.code is not null and p.vip_tier_code is distinct from t.code;
  get diagnostics n = row_count;
  return n;
end $$;

-- Weights: shared device +40, shared id +60, shared bank +50, >50 ok clicks/24h +20, referral pair sharing device/bank +50.
-- Each signal kind counts once per user; score capped 100; low < 30, medium < 60, else high. Returns flags newly inserted.
create function public.refresh_risk_scores() returns int
language plpgsql security definer set search_path = pg_catalog, public as $$
declare
  n int := 0;
  k int;
begin
  insert into public.fraud_flags (user_id, type, score, evidence, dedupe_key)
  select (array_agg(d.user_id order by p.created_at desc))[1], 'multi_account_device', 40,
         jsonb_build_object('device_hash', d.device_hash, 'user_ids', array_agg(distinct d.user_id)), 'mad:' || d.device_hash
    from public.user_devices d join public.profiles p on p.id = d.user_id
   group by d.device_hash having count(distinct d.user_id) >= 2
  on conflict (dedupe_key) do nothing;
  get diagnostics k = row_count; n := n + k;

  insert into public.fraud_flags (user_id, type, score, evidence, dedupe_key)
  select (array_agg(x.user_id order by p.created_at desc))[1], 'shared_identity', 60,
         jsonb_build_object('user_ids', array_agg(distinct x.user_id)), 'sid:' || x.id_number_hmac
    from public.kyc_profiles x join public.profiles p on p.id = x.user_id
   group by x.id_number_hmac having count(distinct x.user_id) >= 2
  on conflict (dedupe_key) do nothing;
  get diagnostics k = row_count; n := n + k;

  insert into public.fraud_flags (user_id, type, score, evidence, dedupe_key)
  select (array_agg(b.user_id order by p.created_at desc))[1], 'shared_bank_account', 50,
         jsonb_build_object('bank_bin', b.bank_bin, 'user_ids', array_agg(distinct b.user_id)),
         'sba:' || b.bank_bin || ':' || b.account_number
    from public.bank_accounts b join public.profiles p on p.id = b.user_id
   group by b.bank_bin, b.account_number having count(distinct b.user_id) >= 2
  on conflict (dedupe_key) do nothing;
  get diagnostics k = row_count; n := n + k;

  insert into public.fraud_flags (user_id, type, score, evidence, dedupe_key)
  select c.user_id, 'abnormal_clicks', 20, jsonb_build_object('clicks_24h', count(*)), 'abc:' || c.user_id || ':' || current_date
    from public.clicks c where c.status = 'ok' and c.created_at > now() - interval '24 hours'
   group by c.user_id having count(*) > 50
  on conflict (dedupe_key) do nothing;
  get diagnostics k = row_count; n := n + k;

  insert into public.fraud_flags (user_id, type, score, evidence, dedupe_key)
  select r.referee_id, 'self_referral', 50, jsonb_build_object('referral_id', r.id, 'referrer_id', r.referrer_id), 'srf:' || r.id
    from public.referrals r
   where exists (select 1 from public.user_devices a join public.user_devices b on a.device_hash = b.device_hash
                  where a.user_id = r.referrer_id and b.user_id = r.referee_id)
      or exists (select 1 from public.bank_accounts a join public.bank_accounts b
                    on a.bank_bin = b.bank_bin and a.account_number = b.account_number
                  where a.user_id = r.referrer_id and b.user_id = r.referee_id)
  on conflict (dedupe_key) do nothing;
  get diagnostics k = row_count; n := n + k;

  with sig as (
    select d.user_id, 'dev' kind, 40 pts from public.user_devices d
      where exists (select 1 from public.user_devices e where e.device_hash = d.device_hash and e.user_id <> d.user_id)
    union select x.user_id, 'kyc', 60 from public.kyc_profiles x
      where exists (select 1 from public.kyc_profiles y where y.id_number_hmac = x.id_number_hmac and y.user_id <> x.user_id)
    union select b.user_id, 'bank', 50 from public.bank_accounts b
      where exists (select 1 from public.bank_accounts e where e.bank_bin = b.bank_bin and e.account_number = b.account_number
                       and e.user_id <> b.user_id)
    union select c.user_id, 'clicks', 20 from public.clicks c
      where c.status = 'ok' and c.created_at > now() - interval '24 hours' group by c.user_id having count(*) > 50
    union select f.user_id, 'ref', 50 from public.fraud_flags f where f.type = 'self_referral' and f.status = 'open'),
  s as (select user_id, least(100, sum(pts))::int score from sig where user_id is not null group by user_id),
  up as (
    insert into public.user_risk (user_id, risk_score, level, updated_at)
    select s.user_id, s.score, case when s.score < 30 then 'low' when s.score < 60 then 'medium' else 'high' end, now() from s
    on conflict (user_id) do update set risk_score = excluded.risk_score, level = excluded.level, updated_at = now()
    returning user_id)
  update public.user_risk r set risk_score = 0, level = 'low', updated_at = now()
   where r.risk_score <> 0 and not exists (select 1 from up where up.user_id = r.user_id);
  return n;
end $$;
