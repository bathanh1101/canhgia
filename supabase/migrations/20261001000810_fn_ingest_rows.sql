-- One AccessTrade conversion row -> order + ledger. Raises on bad input; the caller's savepoint absorbs it.
create function private.ingest_one(p_row jsonb) returns text
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare
  v_conv bigint := (p_row ->> 'conversion_id')::bigint;
  v_status int := (p_row ->> 'status')::int;
  v_conf int := coalesce((p_row ->> 'is_confirmed')::int, 0);
  v_comm bigint := round(coalesce((p_row ->> 'commission')::numeric, 0))::bigint;
  v_val bigint := round(coalesce((p_row ->> 'transaction_value')::numeric, 0))::bigint;
  v_upd timestamptz := nullif(p_row ->> 'update_time', '')::timestamptz;
  v_txn text := nullif(p_row ->> 'transaction_id', '');
  v_utm text := nullif(p_row ->> 'utm_content', '');
  m public.merchants;
  o public.orders;
  v_man public.orders;
  v_uid uuid;
  v_click bigint;
  v_old public.credit_state;
  v_state public.credit_state;
  v_share int;
  v_vip int;
  v_cb bigint;
  v_ctime timestamptz;
  v_wd timestamptz;
  v_result text;
begin
  if v_conv is null then raise exception 'conversion_id required'; end if;
  if v_status is null or v_status not in (0, 1, 2) then raise exception 'invalid status'; end if;
  if v_comm < 0 or v_val < 0 then raise exception 'negative amount'; end if;
  select * into m from public.merchants
   where at_campaign_id = p_row ->> 'merchant' or id = p_row ->> 'merchant'
   order by (id = p_row ->> 'merchant') desc limit 1;
  if not found then raise exception 'unknown merchant %', p_row ->> 'merchant'; end if;

  select * into o from public.orders where conversion_id = v_conv for update;
  if found then
    if o.update_time is not null and v_upd is not null and o.update_time > v_upd then
      return 'skipped';  -- stale page: never regress newer state
    end if;
    if o.update_time is not null and v_upd is not null and o.update_time = v_upd
       and o.at_status is not distinct from v_status and o.commission_vnd = v_comm and o.is_confirmed = v_conf then
      return 'skipped';
    end if;
    v_result := 'updated';
    if o.user_id is null then
      select * into v_uid, v_click from private.match_utm(v_utm, m.id);
      update public.orders set user_id = v_uid, click_id = v_click, matched_by = case when v_uid is not null then 'utm_content' end
       where id = o.id returning * into o;
    end if;
  else
    select * into v_uid, v_click from private.match_utm(v_utm, m.id);
    select * into v_man from public.orders x
     where v_txn is not null and x.source = 'manual' and x.conversion_id is null and x.merchant_id = m.id
       and x.transaction_id_norm = upper(regexp_replace(v_txn, '[^A-Za-z0-9]', '', 'g')) for update;
    if found and (v_uid is null or v_uid = v_man.user_id) then
      update public.orders set conversion_id = v_conv, matched_by = 'transaction_id' where id = v_man.id returning * into o;
      v_result := 'updated';
    else
      if found then  -- never silently reassign a manual claim
        perform private.flag(v_man.user_id, 'order_claim_conflict', 70,
          jsonb_build_object('manual_order_id', v_man.id, 'conversion_id', v_conv, 'claimed_by', v_uid), 'occ:' || v_man.id);
      end if;
      insert into public.orders (source, conversion_id, merchant_id, transaction_id, utm_content, user_id, click_id, matched_by)
      values ('accesstrade', v_conv, m.id, v_txn, v_utm, v_uid, v_click, case when v_uid is not null then 'utm_content' end)
      returning * into o;
      v_result := case when v_uid is null then 'unmatched' else 'inserted' end;
    end if;
  end if;
  insert into public.order_raw (order_id, raw) values (o.id, p_row)
  on conflict (order_id) do update set raw = excluded.raw;

  v_old := o.credit_state;
  if o.source = 'manual' then  -- keeps credited + resolution amount; only AT status 2 reverses
    v_cb := o.user_cashback_vnd;
    v_state := case when v_status = 2 then 'reversed' else 'credited' end;
  elsif o.user_id is null then
    v_cb := 0; v_state := 'none';
  else
    v_share := o.user_share_bps; v_vip := o.vip_bonus_bps;
    if v_share is null then  -- snapshot once: (merchant,category) > (merchant) > (default)
      select r.user_share_bps into v_share from public.cashback_rules r
       where (r.merchant_id is null or r.merchant_id = m.id)
         and (r.category_key is null or r.category_key = nullif(p_row ->> 'product_category', ''))
       order by (r.merchant_id is not null) desc, (r.category_key is not null) desc limit 1;
      select coalesce(t.bonus_bps, 0) into v_vip from public.profiles p
        left join public.vip_tiers t on t.code = p.vip_tier_code where p.id = o.user_id;
      v_share := coalesce(v_share, 0);
    end if;
    v_cb := private.compute_cashback(v_comm, v_share, v_vip);
    v_state := case when v_status = 2 then (case when v_old in ('credited', 'reversed') then 'reversed' else 'cancelled' end)
                    when v_status = 1 and v_conf = 1 then 'credited' else 'pending' end;
  end if;
  v_ctime := o.confirmed_time; v_wd := o.withdrawable_at;
  if v_state = 'credited' and v_ctime is null then
    v_ctime := coalesce(nullif(p_row ->> 'confirmed_time', '')::timestamptz, now());
    v_wd := v_ctime + make_interval(days => m.hold_days);
  end if;

  update public.orders set
    at_status = v_status, is_confirmed = v_conf, commission_vnd = v_comm, value_vnd = v_val, update_time = v_upd,
    transaction_id = coalesce(o.transaction_id, v_txn), product_id = p_row ->> 'product_id',
    product_name = p_row ->> 'product_name', category_key = nullif(p_row ->> 'product_category', ''),
    product_price = (p_row ->> 'product_price')::numeric::bigint, product_quantity = (p_row ->> 'product_quantity')::int,
    click_time = nullif(p_row ->> 'click_time', '')::timestamptz, order_time = nullif(p_row ->> 'transaction_time', '')::timestamptz,
    utm_content = coalesce(o.utm_content, v_utm), user_share_bps = coalesce(o.user_share_bps, v_share),
    vip_bonus_bps = coalesce(o.vip_bonus_bps, v_vip), user_cashback_vnd = v_cb, credit_state = v_state,
    confirmed_time = v_ctime, withdrawable_at = v_wd
   where id = o.id returning * into o;

  perform private.apply_order_ledger(o.id);
  perform private.referral_step(o.id);
  if o.user_id is not null and v_state is distinct from v_old and v_state <> 'none' then
    perform private.notify(o.user_id, 'order',
      case v_state when 'credited' then 'Đơn hàng đã được duyệt' when 'pending' then 'Đã ghi nhận đơn hàng'
                   else 'Đơn hàng bị hủy' end,
      m.name || ' - ' || o.user_cashback_vnd || 'đ hoàn tiền',
      jsonb_build_object('order_id', o.id, 'state', v_state));
  end if;
  return v_result;
end $$;

-- Page ingest: savepoint per row; a bad row -> sync_errors + 'error', the page continues.
create function public.ingest_at_transactions(p_job text, p_rows jsonb)
returns table (conversion_id bigint, status text)
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare
  r jsonb;
  v_status text;
  v_conv bigint;
begin
  if p_rows is null or jsonb_typeof(p_rows) <> 'array' then
    perform private.raise_code('invalid_input', '{"field":"p_rows"}');
  end if;
  for r in select e.value from jsonb_array_elements(p_rows) e order by e.value ->> 'conversion_id' loop  -- stable lock order across pages
    v_conv := null;
    begin
      v_conv := (r ->> 'conversion_id')::bigint;
      v_status := private.ingest_one(r);
    exception when others then
      insert into public.sync_errors (job, conversion_id, raw, error) values (p_job, v_conv, r, sqlerrm);
      v_status := 'error';
    end;
    conversion_id := v_conv; status := v_status;
    return next;
  end loop;
end $$;
