-- Read models for the app, landing page and extension. Callable by anon; DEFINER because commission/rule tables are
-- admin-only under RLS (only derived numbers leave). Every limit is clamped.

-- commission rate (bps of order value): (merchant,category) > (merchant); 0 = unknown
create function private.comm_bps(p_merchant text, p_category text) returns int
language sql stable security definer set search_path = pg_catalog, public as $$
  select coalesce((select c.commission_rate_bps from public.campaign_commissions c
                    where c.merchant_id = p_merchant and c.category_key in (coalesce(p_category, ''), '')
                    order by (c.category_key <> '') desc limit 1), 0)
$$;

-- user share of commission: same precedence as ingest_one (merchant+category > merchant > default)
create function private.share_bps(p_merchant text, p_category text) returns int
language sql stable security definer set search_path = pg_catalog, public as $$
  select coalesce((select r.user_share_bps from public.cashback_rules r
                    where (r.merchant_id is null or r.merchant_id = p_merchant)
                      and (r.category_key is null or r.category_key = p_category)
                    order by (r.merchant_id is not null) desc, (r.category_key is not null) desc limit 1), 0)
$$;

-- bonus bps of the calling user's tier (0 for anon)
create function private.caller_vip_bps() returns int
language sql stable security definer set search_path = pg_catalog, public as $$
  select coalesce((select t.bonus_bps from public.profiles p join public.vip_tiers t on t.code = p.vip_tier_code
                    where p.id = auth.uid()), 0)
$$;

create function private.est_cashback(p_merchant text, p_category text, p_price bigint, p_vip int) returns bigint
language sql stable security definer set search_path = pg_catalog, public as $$
  select private.compute_cashback(coalesce(p_price, 0) * private.comm_bps(p_merchant, p_category) / 10000,
                                  private.share_bps(p_merchant, p_category), p_vip)
$$;

-- prefix-AND tsquery over accent-free words; null when nothing searchable
create function private.search_tsquery(p_q text) returns tsquery
language sql stable set search_path = pg_catalog, extensions, public as $$
  select to_tsquery('simple', string_agg(w || ':*', ' & '))
    from regexp_split_to_table(regexp_replace(coalesce(private.norm_vn(p_q), ''), '[^a-z0-9]+', ' ', 'g'), ' ') w
   where w <> ''
$$;

create function public.search_offers(p_q text, p_merchants text[] default null, p_sort text default 'relevance',
  p_limit int default 20, p_offset int default 0)
returns table (offer_id bigint, product_group_id bigint, merchant_id text, name text, image_url text, price_vnd bigint,
  rate_bps int, est_cashback_vnd bigint, offers_in_group int)
language plpgsql stable security definer set search_path = pg_catalog, public, extensions as $$
declare
  q tsquery := private.search_tsquery(p_q);
  v_vip int := private.caller_vip_bps();
begin
  if p_sort is null or p_sort not in ('relevance', 'price_asc', 'price_desc', 'cashback_desc') then
    perform private.raise_code('invalid_input', '{"field":"p_sort"}');
  end if;
  if q is null then return; end if;
  return query
    with hit as (
      select o.id, o.product_group_id g, o.merchant_id m, o.name n, o.image_url i, o.price p, o.category_key c,
             o.cashback_eligible ok, ts_rank(o.fts, q) rk
        from public.offers o join public.merchants mm on mm.id = o.merchant_id and mm.is_active
       where o.fts @@ q and o.price is not null and (p_merchants is null or o.merchant_id = any(p_merchants))),
    calc as (
      select h.*, case when h.ok then private.est_cashback(h.m, h.c, h.p, v_vip) else 0 end cb from hit h)
    select c.id, c.g, c.m, c.n, c.i, c.p,
           case when c.p > 0 then (c.cb * 10000 / c.p)::int else 0 end, c.cb,
           case when c.g is null then 1
                else (select count(*)::int from public.offers x where x.product_group_id = c.g and x.price is not null) end
      from calc c
     order by case p_sort when 'relevance' then c.rk::float8 when 'cashback_desc' then c.cb::float8 end desc nulls last,
              case p_sort when 'price_asc' then c.p end asc,
              case p_sort when 'price_desc' then c.p end desc,
              c.p asc, c.id
     limit greatest(1, least(coalesce(p_limit, 20), 50)) offset greatest(0, coalesce(p_offset, 0));
end $$;

-- compare needs >= 2 offers; is_mall = shop name says Mall/Official (datafeed has no mall flag)
create function public.get_compare(p_group_id bigint)
returns table (offer_id bigint, merchant_id text, shop_name text, name text, url text, image_url text, price_vnd bigint,
  list_price_vnd bigint, est_cashback_vnd bigint, effective_price_vnd bigint, is_mall boolean, cashback_eligible boolean)
language plpgsql stable security definer set search_path = pg_catalog, public as $$
declare
  v_vip int := private.caller_vip_bps();
begin
  return query
    with c as (
      select o.*, case when o.cashback_eligible then private.est_cashback(o.merchant_id, o.category_key, o.price, v_vip) else 0 end cb
        from public.offers o join public.merchants m on m.id = o.merchant_id and m.is_active
       where o.product_group_id = p_group_id and o.price is not null)
    select c.id, c.merchant_id, c.shop_name, c.name, c.url, c.image_url, c.price, c.list_price, c.cb, c.price - c.cb,
           coalesce(c.shop_name ~* '(mall|official)', false), c.cashback_eligible
      from c where (select count(*) from c) >= 2
     order by c.price - c.cb, c.id;
end $$;

create function public.get_price_history(p_group_id bigint, p_days int) returns table (day date, min_price_vnd bigint)
language sql stable security definer set search_path = pg_catalog, public as $$
  select s.day, min(s.price)::bigint
    from public.price_snapshots s join public.offers o on o.id = s.offer_id
   where o.product_group_id = p_group_id and s.day >= current_date - greatest(1, least(coalesce(p_days, 30), 365))
   group by s.day order by s.day
$$;

-- rates are relative to order value; VIP tier = p_tier_code, else the caller's own tier
create function public.estimate_cashback(p_merchant_id text, p_category_key text, p_order_value bigint,
  p_tier_code text default null)
returns table (commission_vnd bigint, base_cashback_vnd bigint, vip_bonus_vnd bigint, user_cashback_vnd bigint,
  app_keeps_vnd bigint, base_rate_bps int, vip_rate_bps int)
language plpgsql stable security definer set search_path = pg_catalog, public as $$
declare
  v_comm bigint;
  v_share int;
  v_vip int;
  v_base bigint;
  v_user bigint;
begin
  if p_order_value is null or p_order_value <= 0 or p_order_value > 1000000000000 then
    perform private.raise_code('invalid_input', '{"field":"p_order_value"}');
  end if;
  if not exists (select 1 from public.merchants m where m.id = p_merchant_id and m.is_active) then
    perform private.raise_code('invalid_input', '{"field":"p_merchant_id"}');
  end if;
  if p_tier_code is null then
    v_vip := private.caller_vip_bps();
  else
    select t.bonus_bps into v_vip from public.vip_tiers t where t.code = p_tier_code;
    if not found then perform private.raise_code('invalid_input', '{"field":"p_tier_code"}'); end if;
  end if;
  v_comm := p_order_value * private.comm_bps(p_merchant_id, p_category_key) / 10000;
  v_share := private.share_bps(p_merchant_id, p_category_key);
  v_base := private.compute_cashback(v_comm, v_share, 0);
  v_user := private.compute_cashback(v_comm, v_share, v_vip);
  return query select v_comm, v_base, v_user - v_base, v_user, v_comm - v_user,
    (v_base * 10000 / p_order_value)::int, ((v_user - v_base) * 10000 / p_order_value)::int;
end $$;

create function public.get_merchant_rates()
returns table (merchant_id text, name text, badge_letter text, domains text[], max_user_rate_bps int,
  datafeed_enabled boolean, extension_enabled boolean, activation_hours int, hold_days int, link_api text)
language sql stable security definer set search_path = pg_catalog, public as $$
  select m.id, m.name, m.badge_letter, m.domains,
         coalesce(m.max_user_rate_bps,
                  (select max(private.compute_cashback(c.commission_rate_bps::bigint, private.share_bps(m.id, nullif(c.category_key, '')), 0))
                     from public.campaign_commissions c where c.merchant_id = m.id)::int, 0),
         m.datafeed_enabled, m.extension_enabled, m.activation_hours, m.hold_days, m.link_api
    from public.merchants m where m.is_active order by m.sort, m.id
$$;

create function public.get_public_settings() returns jsonb
language sql stable security definer set search_path = pg_catalog, public as $$
  select jsonb_build_object(
    'min_withdraw_vnd', (select value from public.app_settings where key = 'min_withdraw_vnd'),
    'withdraw_daily_cap_vnd', (select value from public.app_settings where key = 'withdraw_daily_cap_vnd'),
    'referral_bonus_vnd', (select value from public.app_settings where key = 'referral_bonus_vnd'),
    'withdraw_eta_text', (select value from public.app_settings where key = 'withdraw_eta_text'),
    'landing_stats', (select value from public.app_settings where key = 'landing_stats'),
    'max_rate_bps', coalesce((select max(r.max_user_rate_bps) from public.get_merchant_rates() r), 0),
    'active_merchants', (select count(*) from public.merchants where is_active))
$$;
