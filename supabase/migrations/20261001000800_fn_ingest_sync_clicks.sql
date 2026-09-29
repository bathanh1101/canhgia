-- Ledger/ingest helpers (private) + per-row AccessTrade ingest. All SECURITY DEFINER, pinned search_path.
create function private.compute_cashback(p_commission bigint, p_share_bps int, p_vip_bps int) returns bigint
language sql immutable set search_path = pg_catalog as $$
  select greatest(0, least(p_commission, (p_commission * (coalesce(p_share_bps, 0) + coalesce(p_vip_bps, 0))) / 10000))
$$;

create function private.flag(p_user uuid, p_type public.fraud_type, p_score int, p_evidence jsonb, p_dedupe text)
returns void language sql security definer set search_path = pg_catalog, public as $$
  insert into public.fraud_flags (user_id, type, score, evidence, dedupe_key)
  values (p_user, p_type, p_score, p_evidence, p_dedupe) on conflict (dedupe_key) do nothing
$$;

create function private.notify(p_user uuid, p_type public.notification_type, p_title text, p_body text, p_data jsonb default '{}')
returns void language sql security definer set search_path = pg_catalog, public as $$
  insert into public.notifications (user_id, type, title, body, data) values (p_user, p_type, p_title, p_body, p_data)
$$;

create function private.notify_admins(p_title text, p_body text, p_data jsonb) returns void
language sql security definer set search_path = pg_catalog, public as $$
  insert into public.notifications (user_id, type, title, body, data)
  select a.user_id, 'system', p_title, p_body, p_data from public.admins a
$$;

-- utm_content 'u<short_id>c<click_id>'; click must belong to that user
create function private.match_utm(p_utm text, out o_user uuid, out o_click bigint)
language plpgsql stable security definer set search_path = pg_catalog, public as $$
declare
  m text[] := regexp_match(coalesce(p_utm, ''), '^u(\d+)c(\d+)$');
begin
  if m is null then return; end if;
  select c.user_id, c.id into o_user, o_click
    from public.clicks c join public.profiles p on p.id = c.user_id
   where c.id = m[2]::bigint and p.short_id = m[1]::bigint;
end $$;

-- FM-5: post target - sum(ledger for order); one rule for flip-flop, commission edits, manual attach
create function private.apply_order_ledger(p_order uuid) returns void
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare
  o public.orders;
  v_delta bigint;
  v_n bigint;
begin
  select * into o from public.orders where id = p_order;
  if o.user_id is null then return; end if;
  select o.user_cashback_vnd * (o.credit_state = 'credited')::int - coalesce(sum(l.amount_vnd), 0), count(*)
    into v_delta, v_n from public.wallet_ledger l where l.order_id = o.id;
  if v_delta = 0 then return; end if;
  begin
    insert into public.wallet_ledger (user_id, entry_type, amount_vnd, order_id, idempotency_key, available_at, note)
    values (o.user_id,
            case when v_delta > 0 then (case when o.source = 'manual' then 'manual_credit' else 'cashback_credit' end)
                 else (case when o.source = 'manual' then 'manual_reversal' else 'cashback_reversal' end) end::public.ledger_entry_type,
            v_delta, o.id, 'ord:' || o.id || ':' || v_n,
            case when v_delta > 0 then o.withdrawable_at end, 'order ' || o.credit_state);
  exception when others then
    if sqlerrm <> 'insufficient_balance' then raise; end if;
    perform private.flag(o.user_id, 'negative_balance_risk', 50,
      jsonb_build_object('order_id', o.id, 'delta', v_delta), 'nbr:' || o.id || ':' || v_n);
    perform private.notify_admins('Ví âm nếu hoàn tiền', 'Đơn ' || o.id || ' cần xử lý thủ công',
      jsonb_build_object('order_id', o.id, 'user_id', o.user_id, 'delta', v_delta));
  end;
end $$;

-- Referral: qualify on first credited order >= 200.000d; reverse/void when that order is reversed.
create function private.referral_step(p_order uuid) returns void
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare
  o public.orders;
  r public.referrals;
  v_bonus bigint;
  v_status public.referral_status;
  v_shared text;
begin
  select * into o from public.orders where id = p_order;
  if o.user_id is null then return; end if;
  if o.credit_state = 'credited' then
    select * into r from public.referrals where referee_id = o.user_id and status = 'pending' for update;
    if not found or o.value_vnd < 200000 then return; end if;
    v_bonus := least((select (value #>> '{}')::bigint from public.app_settings where key = 'referral_bonus_vnd'),
                     o.commission_vnd * 30 / 100);
    select case when exists (select 1 from public.kyc_profiles a join public.kyc_profiles b
                              on a.id_number_hmac = b.id_number_hmac
                            where a.user_id = r.referrer_id and b.user_id = r.referee_id) then 'identity'
                when exists (select 1 from public.user_devices a join public.user_devices b on a.device_hash = b.device_hash
                            where a.user_id = r.referrer_id and b.user_id = r.referee_id) then 'device'
                when exists (select 1 from public.bank_accounts a join public.bank_accounts b
                              on a.bank_bin = b.bank_bin and a.account_number = b.account_number
                            where a.user_id = r.referrer_id and b.user_id = r.referee_id) then 'bank' end into v_shared;
    if v_shared = 'identity' then
      v_status := 'void';
      perform private.flag(r.referee_id, 'shared_identity', 80, jsonb_build_object('referral_id', r.id), 'ref:' || r.id);
    elsif v_shared is not null then
      v_status := 'held';
      perform private.flag(r.referee_id, case v_shared when 'device' then 'multi_account_device' else 'shared_bank_account' end,
        60, jsonb_build_object('referral_id', r.id), 'ref:' || r.id);
    elsif v_bonus > 0 then
      v_status := 'rewarded';
      insert into public.wallet_ledger (user_id, entry_type, amount_vnd, referral_id, idempotency_key, available_at, note)
      values (r.referrer_id, 'referral_bonus', v_bonus, r.id, 'ref:' || r.id, now() + interval '30 days', 'referral bonus');
      perform private.notify(r.referrer_id, 'referral', 'Thưởng giới thiệu', 'Bạn nhận thưởng giới thiệu bạn bè',
        jsonb_build_object('referral_id', r.id, 'amount_vnd', v_bonus));
    else
      v_status := 'qualified';
    end if;
    update public.referrals set status = v_status, qualified_order_id = o.id, bonus_vnd = greatest(v_bonus, 0) where id = r.id;
  elsif o.credit_state in ('cancelled', 'reversed') then
    select * into r from public.referrals
     where qualified_order_id = o.id and status in ('rewarded', 'held', 'qualified') for update;
    if not found then return; end if;
    if r.status = 'rewarded' then
      begin
        insert into public.wallet_ledger (user_id, entry_type, amount_vnd, referral_id, idempotency_key, note)
        values (r.referrer_id, 'referral_reversal', -r.bonus_vnd, r.id, 'refrev:' || r.id, 'order reversed');
      exception when others then
        if sqlerrm <> 'insufficient_balance' then raise; end if;
        perform private.flag(r.referrer_id, 'negative_balance_risk', 50, jsonb_build_object('referral_id', r.id), 'nbr:ref:' || r.id);
      end;
    end if;
    update public.referrals set status = 'void' where id = r.id;
  end if;
end $$;
