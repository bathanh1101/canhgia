-- Sync bookkeeping, AT rate limiter, click creation, catalog upserts. Service-role only (grants in 001000).
create function public.at_rate_limit_take(p_cost int, p_bucket text default 'transactions') returns boolean
language plpgsql security definer set search_path = pg_catalog, public as $$
declare
  b public.at_rate_bucket;
  v_tokens numeric;
begin
  select * into b from public.at_rate_bucket where bucket = p_bucket for update;
  if not found or p_cost is null or p_cost < 1 then
    perform private.raise_code('invalid_input', jsonb_build_object('field', 'p_bucket'));
  end if;
  v_tokens := least(b.capacity, b.tokens + b.refill_per_min * extract(epoch from now() - b.refilled_at) / 60);
  if v_tokens >= p_cost then
    update public.at_rate_bucket set tokens = v_tokens - p_cost, refilled_at = now() where bucket = p_bucket;
    return true;
  end if;
  update public.at_rate_bucket set tokens = v_tokens, refilled_at = now() where bucket = p_bucket;
  return false;
end $$;

create function public.sync_lock(p_job text, p_ttl_s int) returns boolean
language plpgsql security definer set search_path = pg_catalog, public as $$
declare
  n int;
begin
  insert into public.sync_state (job, locked_until) values (p_job, now() + make_interval(secs => p_ttl_s))
  on conflict (job) do update set locked_until = excluded.locked_until
    where public.sync_state.locked_until is null or public.sync_state.locked_until < now();
  get diagnostics n = row_count;
  return n = 1;
end $$;

create function public.sync_save(p_job text, p_cursor jsonb) returns void
language sql security definer set search_path = pg_catalog, public as $$
  update public.sync_state set cursor = p_cursor where job = p_job
$$;

create function public.sync_finish(p_job text, p_success boolean, p_error text, p_window_until timestamptz) returns void
language sql security definer set search_path = pg_catalog, public as $$
  update public.sync_state set
    locked_until = null,
    last_error = case when p_success then null else p_error end,
    last_success_at = case when p_success then p_window_until else last_success_at end,
    cursor = case when p_success then null else cursor end
  where job = p_job
$$;

create function public.create_click(p_user_id uuid, p_merchant_id text, p_origin_url text, p_resolved_url text,
  p_offer_id bigint, p_source public.click_source, p_device_hash text)
returns table (click_id bigint, utm_content text, aff_link text, short_link text)
language plpgsql security definer set search_path = pg_catalog, public as $$
declare
  p public.profiles;
  m public.merchants;
  c public.clicks;
  v_limit int;
begin
  perform pg_advisory_xact_lock(hashtextextended('click:' || p_user_id, 0));
  select * into p from public.profiles where id = p_user_id;
  if not found then perform private.raise_code('invalid_input', '{"field":"p_user_id"}'); end if;
  if p.locked_at is not null then perform private.raise_code('account_locked'); end if;
  select * into m from public.merchants where id = p_merchant_id and is_active;
  if not found then perform private.raise_code('invalid_input', '{"field":"p_merchant_id"}'); end if;

  select * into c from public.clicks x
   where x.user_id = p_user_id and x.merchant_id = m.id and x.aff_link is not null and x.status = 'ok'
     and x.resolved_url is not distinct from p_resolved_url
     and x.created_at > now() - make_interval(hours => m.activation_hours)
   order by x.id desc limit 1;
  if found then
    return query select c.id, c.utm_content, c.aff_link, c.short_link;
    return;
  end if;

  select (value #>> '{}')::int into v_limit from public.app_settings where key = 'click_limit_per_hour';
  if (select count(*) from public.clicks x where x.user_id = p_user_id and x.status <> 'failed'
        and x.created_at > now() - interval '1 hour') >= coalesce(v_limit, 30) then
    perform private.raise_code('rate_limited');
  end if;

  insert into public.clicks (user_id, merchant_id, origin_url, resolved_url, offer_id, source, device_hash)
  values (p_user_id, m.id, p_origin_url, p_resolved_url, p_offer_id, p_source, p_device_hash) returning * into c;
  update public.clicks set utm_content = 'u' || p.short_id || 'c' || c.id where id = c.id returning * into c;
  return query select c.id, c.utm_content, null::text, null::text;
end $$;

create function public.set_click_link(p_click_id bigint, p_aff_link text, p_short_link text) returns void
language sql security definer set search_path = pg_catalog, public as $$
  update public.clicks set aff_link = p_aff_link, short_link = p_short_link,
    status = case when p_aff_link is null then 'failed' else 'ok' end::public.click_status
  where id = p_click_id
$$;

create function public.upsert_offers(p_merchant_id text, p_rows jsonb) returns table (upserted int, snapshots int)
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare
  r jsonb;
  v_id bigint;
  v_grp bigint;
  v_norm text;
  v_price bigint;
begin
  upserted := 0; snapshots := 0;
  if jsonb_typeof(p_rows) <> 'array' then perform private.raise_code('invalid_input', '{"field":"p_rows"}'); end if;
  for r in select * from jsonb_array_elements(p_rows) loop
    begin  -- one bad row never blocks the page
      v_norm := private.norm_vn(r ->> 'name');
      v_price := (r ->> 'price')::numeric::bigint;
      v_grp := null;
      if nullif(r ->> 'sku', '') is not null and nullif(r ->> 'brand', '') is not null then
        insert into public.product_groups (group_key) values (lower(r ->> 'brand') || ':' || lower(r ->> 'sku'))
        on conflict (group_key) do update set group_key = excluded.group_key returning id into v_grp;
      end if;
      insert into public.offers (merchant_id, external_product_id, sku, brand, name, name_norm, fts, url, image_url,
        category_key, price, list_price, shop_name, cashback_eligible, product_group_id)
      values (p_merchant_id, r ->> 'external_product_id', r ->> 'sku', r ->> 'brand', r ->> 'name', v_norm,
        to_tsvector('simple', coalesce(v_norm, '')), r ->> 'url', r ->> 'image_url', r ->> 'category_key', v_price,
        (r ->> 'list_price')::numeric::bigint, r ->> 'shop_name', coalesce((r ->> 'cashback_eligible')::boolean, true), v_grp)
      on conflict (merchant_id, external_product_id) do update set
        sku = excluded.sku, brand = excluded.brand, name = excluded.name, name_norm = excluded.name_norm,
        fts = excluded.fts, url = excluded.url, image_url = excluded.image_url, category_key = excluded.category_key,
        price = excluded.price, list_price = excluded.list_price, shop_name = excluded.shop_name,
        cashback_eligible = excluded.cashback_eligible, product_group_id = excluded.product_group_id, updated_at = now()
      returning id into v_id;
      upserted := upserted + 1;
      if v_price is not null then
        insert into public.price_snapshots (offer_id, day, price) values (v_id, current_date, v_price)
        on conflict (offer_id, day) do update set price = excluded.price;
        snapshots := snapshots + 1;
      end if;
    exception when others then
      insert into public.sync_errors (job, raw, error) values ('upsert_offers', r, sqlerrm);
    end;
  end loop;
  return next;
end $$;

create function public.upsert_vouchers(p_rows jsonb) returns int
language plpgsql security definer set search_path = pg_catalog, public as $$
declare
  r jsonb;
  n int := 0;
begin
  if jsonb_typeof(p_rows) <> 'array' then perform private.raise_code('invalid_input', '{"field":"p_rows"}'); end if;
  for r in select * from jsonb_array_elements(p_rows) loop
    begin
      insert into public.vouchers (merchant_id, external_id, code, title, description, discount_text, url, starts_at, ends_at)
      values (r ->> 'merchant_id', r ->> 'external_id', r ->> 'code', r ->> 'title', r ->> 'description',
        r ->> 'discount_text', r ->> 'url', (r ->> 'starts_at')::timestamptz, (r ->> 'ends_at')::timestamptz)
      on conflict (merchant_id, external_id) do update set code = excluded.code, title = excluded.title,
        description = excluded.description, discount_text = excluded.discount_text, url = excluded.url,
        starts_at = excluded.starts_at, ends_at = excluded.ends_at, updated_at = now();
      n := n + 1;
    exception when others then
      insert into public.sync_errors (job, raw, error) values ('upsert_vouchers', r, sqlerrm);
    end;
  end loop;
  return n;
end $$;

create function public.upsert_campaign_commissions(p_rows jsonb) returns int
language plpgsql security definer set search_path = pg_catalog, public as $$
declare
  r jsonb;
  n int := 0;
begin
  if jsonb_typeof(p_rows) <> 'array' then perform private.raise_code('invalid_input', '{"field":"p_rows"}'); end if;
  for r in select * from jsonb_array_elements(p_rows) loop
    begin
      insert into public.campaign_commissions (merchant_id, category_key, commission_rate_bps)
      values (r ->> 'merchant_id', coalesce(r ->> 'category_key', ''), (r ->> 'commission_rate_bps')::int)
      on conflict (merchant_id, category_key) do update set commission_rate_bps = excluded.commission_rate_bps, updated_at = now();
      n := n + 1;
    exception when others then
      insert into public.sync_errors (job, raw, error) values ('upsert_campaign_commissions', r, sqlerrm);
    end;
  end loop;
  return n;
end $$;
