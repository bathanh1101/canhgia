-- Admin fns: order re-assignment, cashback rules, VIP tiers, settings, user lock, fraud flags (gate + audit row each).

-- Moves an order to another user: old owner's credits are reversed, the new owner gets a fresh posting via
-- apply_order_ledger. An unmatched order (user_id null) is priced + state-derived here for the first time.
create function public.admin_assign_order(p_order_id uuid, p_user_id uuid) returns void
language plpgsql security definer set search_path = pg_catalog, public as $$
declare
  v_admin uuid := private.admin_gate('assign_order', p_order_id::text, jsonb_build_object('user_id', p_user_id));
  o public.orders;
  v_old uuid;
  v_sum bigint;
  v_n bigint;
  v_vip int;
  v_share int;
  v_cb bigint;
  v_state public.credit_state;
  v_conf timestamptz;
  v_hold int;
begin
  select * into o from public.orders where id = p_order_id for update;
  if not found or o.user_id is not distinct from p_user_id then perform private.raise_code('invalid_state'); end if;
  if not exists (select 1 from public.profiles where id = p_user_id) then
    perform private.raise_code('invalid_input', '{"field":"p_user_id"}');
  end if;
  v_old := o.user_id;
  if v_old is not null then  -- take back what the old owner was paid
    select coalesce(sum(l.amount_vnd), 0), count(*) into v_sum, v_n from public.wallet_ledger l where l.order_id = o.id;
    if v_sum <> 0 then
      begin
        insert into public.wallet_ledger (user_id, entry_type, amount_vnd, order_id, idempotency_key, note, created_by)
        values (v_old, case when o.source = 'manual' then 'manual_reversal' else 'cashback_reversal' end::public.ledger_entry_type,
                -v_sum, o.id, 'asg:' || o.id || ':' || v_n, 'order reassigned', v_admin);
      exception when others then
        if sqlerrm <> 'insufficient_balance' then raise; end if;  -- already withdrawn: allow the wallet to go negative
        insert into public.wallet_ledger (user_id, entry_type, amount_vnd, order_id, idempotency_key, note, created_by)
        values (v_old, 'admin_adjustment', -v_sum, o.id, 'asg:' || o.id || ':' || v_n, 'order reassigned', v_admin);
        perform private.flag(v_old, 'negative_balance_risk', 50, jsonb_build_object('order_id', o.id, 'delta', -v_sum),
          'nbr:asg:' || o.id || ':' || v_n);
      end;
    end if;
  end if;

  select coalesce(t.bonus_bps, 0) into v_vip from public.profiles p
    left join public.vip_tiers t on t.code = p.vip_tier_code where p.id = p_user_id;
  v_cb := o.user_cashback_vnd; v_state := o.credit_state; v_conf := o.confirmed_time; v_share := o.user_share_bps;
  if o.source = 'accesstrade' then
    v_share := coalesce(o.user_share_bps, private.share_bps(o.merchant_id, o.category_key));
    v_cb := private.compute_cashback(o.commission_vnd, v_share, v_vip);
    v_state := case when o.at_status = 2 then (case when o.credit_state in ('credited', 'reversed') then 'reversed' else 'cancelled' end)
                    when o.at_status = 1 and o.is_confirmed = 1 then 'credited' else 'pending' end;
    if v_state = 'credited' and v_conf is null then v_conf := now(); end if;
  end if;
  select hold_days into v_hold from public.merchants where id = o.merchant_id;
  update public.orders set user_id = p_user_id, matched_by = 'admin', click_id = null,
    user_share_bps = v_share, vip_bonus_bps = v_vip, user_cashback_vnd = v_cb, credit_state = v_state,
    confirmed_time = v_conf, withdrawable_at = coalesce(withdrawable_at, v_conf + make_interval(days => v_hold))
   where id = o.id;
  perform private.apply_order_ledger(o.id);
  perform private.referral_step(o.id);
  if v_old is not null then
    perform private.notify(v_old, 'order', 'Đơn hàng đã được chuyển', 'Đơn hàng không thuộc tài khoản của bạn',
      jsonb_build_object('order_id', o.id));
  end if;
  perform private.notify(p_user_id, 'order', 'Đơn hàng được ghi nhận cho bạn', 'Đơn hàng đã được gán vào tài khoản của bạn',
    jsonb_build_object('order_id', o.id));
end $$;

-- p_enabled = false stores share 0 (ingest_one has no enabled column and honours the 0)
create function public.admin_upsert_cashback_rule(p_merchant_id text, p_category_key text, p_user_share_bps int,
  p_enabled boolean, p_note text) returns bigint
language plpgsql security definer set search_path = pg_catalog, public as $$
declare
  v_share int := case when p_enabled then p_user_share_bps else 0 end;
  v_id bigint;
begin
  perform private.admin_gate('upsert_cashback_rule', coalesce(p_merchant_id, '*') || '/' || coalesce(p_category_key, '*'),
    jsonb_build_object('share_bps', p_user_share_bps, 'enabled', p_enabled, 'note', p_note));
  if p_user_share_bps is null or p_user_share_bps not between 0 and 10000 or p_enabled is null then
    perform private.raise_code('invalid_input', '{"field":"p_user_share_bps"}');
  end if;
  if p_merchant_id is not null and not exists (select 1 from public.merchants where id = p_merchant_id) then
    perform private.raise_code('invalid_input', '{"field":"p_merchant_id"}');
  end if;
  if v_share + coalesce((select max(bonus_bps) from public.vip_tiers), 0) > 10000 then
    perform private.raise_code('invalid_input', '{"field":"p_user_share_bps","reason":"share_plus_vip_over_100pct"}');
  end if;
  insert into public.cashback_rules (merchant_id, category_key, user_share_bps)
  values (p_merchant_id, nullif(btrim(p_category_key), ''), v_share)
  on conflict (merchant_id, category_key) do update set user_share_bps = excluded.user_share_bps
  returning id into v_id;
  return v_id;
end $$;

create function public.admin_update_vip_tier(p_code text, p_bonus_bps int, p_min_gmv bigint) returns void
language plpgsql security definer set search_path = pg_catalog, public as $$
begin
  perform private.admin_gate('update_vip_tier', p_code, jsonb_build_object('bonus_bps', p_bonus_bps, 'min_gmv', p_min_gmv));
  if p_bonus_bps is null or p_bonus_bps not between 0 and 10000 or p_min_gmv is null or p_min_gmv < 0
     or coalesce((select max(user_share_bps) from public.cashback_rules), 0) + p_bonus_bps > 10000 then
    perform private.raise_code('invalid_input', '{"field":"p_bonus_bps"}');
  end if;
  update public.vip_tiers set bonus_bps = p_bonus_bps, min_gmv_12m_vnd = p_min_gmv where code = p_code;
  if not found then perform private.raise_code('invalid_input', '{"field":"p_code"}'); end if;
end $$;

create function public.admin_set_setting(p_key text, p_value jsonb) returns void
language plpgsql security definer set search_path = pg_catalog, public as $$
declare
  v_ok boolean;
begin
  perform private.admin_gate('set_setting', p_key, jsonb_build_object('value', p_value));
  v_ok := case
    when p_key in ('min_withdraw_vnd', 'withdraw_daily_cap_vnd', 'referral_bonus_vnd', 'click_limit_per_hour', 'auto_payout_limit_vnd')
      then jsonb_typeof(p_value) = 'number' and (p_value #>> '{}') ~ '^\d{1,12}$'
    when p_key = 'auto_payout_enabled' then jsonb_typeof(p_value) = 'boolean'
    when p_key = 'withdraw_eta_text' then jsonb_typeof(p_value) = 'string' and length(p_value #>> '{}') between 1 and 100
    when p_key = 'landing_stats' then jsonb_typeof(p_value) in ('object', 'null')
    else false end;
  if not coalesce(v_ok, false) then perform private.raise_code('invalid_input', '{"field":"p_key"}'); end if;
  update public.app_settings set value = p_value where key = p_key;
  if not found then perform private.raise_code('invalid_input', '{"field":"p_key"}'); end if;
end $$;

create function public.admin_set_user_lock(p_user_id uuid, p_locked boolean, p_reason text) returns void
language plpgsql security definer set search_path = pg_catalog, public as $$
begin
  perform private.admin_gate('set_user_lock', p_user_id::text, jsonb_build_object('locked', p_locked, 'reason', p_reason));
  if p_locked is null or (p_locked and nullif(btrim(p_reason), '') is null) then
    perform private.raise_code('invalid_input', '{"field":"p_reason"}');
  end if;
  update public.profiles set locked_at = case when p_locked then coalesce(locked_at, now()) end where id = p_user_id;
  if not found then perform private.raise_code('invalid_input', '{"field":"p_user_id"}'); end if;
  insert into public.user_risk (user_id, lock_reason) values (p_user_id, case when p_locked then p_reason end)
  on conflict (user_id) do update set lock_reason = excluded.lock_reason, updated_at = now();
end $$;

create function public.admin_update_flag(p_flag_id bigint, p_status public.flag_status) returns void
language plpgsql security definer set search_path = pg_catalog, public as $$
declare
  v_admin uuid := private.admin_gate('update_flag', p_flag_id::text, jsonb_build_object('status', p_status));
begin
  update public.fraud_flags set status = p_status,
    resolved_by = case when p_status = 'open' then null else v_admin end,
    resolved_at = case when p_status = 'open' then null else now() end
   where id = p_flag_id;
  if not found then perform private.raise_code('invalid_state'); end if;
end $$;
