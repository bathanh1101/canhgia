-- User-callable money fns (authenticated). auth.uid() is never taken from params.
create function private.require_uid() returns uuid
language plpgsql stable set search_path = pg_catalog as $$
declare
  v uuid := auth.uid();
begin
  if v is null then perform private.raise_code('forbidden'); end if;
  return v;
end $$;

create function private.bump_hold(p_user uuid) returns void
language sql security definer set search_path = pg_catalog, public as $$
  update public.profiles set withdrawal_hold_until = greatest(coalesce(withdrawal_hold_until, now()), now() + interval '24 hours')
   where id = p_user
$$;

-- Wrong PIN COMMITS the counter (returns instead of raising); 5 wrong -> locked 15 min.
create function public.verify_pin(p_pin text)
returns table (ok boolean, attempts_left int, locked_until timestamptz, pin_token uuid)
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare
  v_uid uuid := private.require_uid();
  u private.user_pins;
  v_fail int;
  v_lock timestamptz;
begin
  select * into u from private.user_pins where user_id = v_uid for update;
  if not found then perform private.raise_code('pin_invalid', '{"reason":"not_set"}'); end if;
  if u.locked_until is not null and u.locked_until > now() then
    perform private.raise_code('pin_locked', jsonb_build_object('locked_until', u.locked_until));
  end if;
  if p_pin is not null and u.pin_hash = extensions.crypt(p_pin, u.pin_hash) then
    update private.user_pins set failed_attempts = 0, locked_until = null where user_id = v_uid;
    ok := true; attempts_left := 5; locked_until := null;
    delete from private.pin_tokens where user_id = v_uid and expires_at < now() - interval '1 hour';
    insert into private.pin_tokens (user_id) values (v_uid) returning token into pin_token;
    return next;
    return;
  end if;
  v_fail := u.failed_attempts + 1;
  if v_fail >= 5 then
    v_lock := now() + interval '15 minutes';
    update private.user_pins set failed_attempts = 0, locked_until = v_lock where user_id = v_uid;
    attempts_left := 0; locked_until := v_lock;
  else
    update private.user_pins set failed_attempts = v_fail where user_id = v_uid;
    attempts_left := 5 - v_fail; locked_until := null;
  end if;
  ok := false; pin_token := null;
  return next;
end $$;

create function private.consume_pin_token(p_user uuid, p_token uuid) returns boolean
language sql security definer set search_path = pg_catalog, public as $$
  with t as (
    update private.pin_tokens set used_at = now()
     where token = p_token and user_id = p_user and used_at is null and expires_at > now() returning 1)
  select exists (select 1 from t)
$$;

create function public.set_withdraw_pin(p_new text, p_pin_token uuid default null) returns void
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare
  v_uid uuid := private.require_uid();
  v_exists boolean;
begin
  if p_new is null or p_new !~ '^\d{6}$' then
    perform private.raise_code('invalid_input', '{"field":"p_new"}');
  end if;
  select exists (select 1 from private.user_pins where user_id = v_uid) into v_exists;
  if v_exists then
    if p_pin_token is null or not private.consume_pin_token(v_uid, p_pin_token) then
      perform private.raise_code('pin_invalid');
    end if;
  elsif not exists (  -- first PIN: fresh email OTP session (amr otp <= 10 min)
    select 1 from jsonb_array_elements(coalesce(auth.jwt() -> 'amr', '[]'::jsonb)) a
     where a ->> 'method' = 'otp' and to_timestamp((a ->> 'timestamp')::bigint) > now() - interval '10 minutes') then
    perform private.raise_code('pin_invalid', '{"reason":"otp_required"}');
  end if;
  if v_exists then
    update private.user_pins set pin_hash = extensions.crypt(p_new, extensions.gen_salt('bf')), failed_attempts = 0,
      locked_until = null, updated_at = now() where user_id = v_uid;
  else  -- two concurrent first-PIN calls: the loser is rejected, never overwrites
    insert into private.user_pins (user_id, pin_hash) values (v_uid, extensions.crypt(p_new, extensions.gen_salt('bf')))
    on conflict (user_id) do nothing;
    if not found then perform private.raise_code('pin_invalid'); end if;
  end if;
  update public.profiles set has_pin = true where id = v_uid;
  if v_exists then perform private.bump_hold(v_uid); end if;
end $$;

create function public.request_withdrawal(p_request_key uuid, p_amount bigint, p_bank_account_id uuid, p_pin_token uuid)
returns table (withdrawal_id uuid, status public.withdrawal_status)
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare
  v_uid uuid := private.require_uid();
  p public.profiles;
  b public.bank_accounts;
  w public.withdrawals;
  v_min bigint;
  v_cap bigint;
begin
  select * into p from public.profiles where id = v_uid for update;  -- serialises this user's requests
  select * into w from public.withdrawals x where x.request_key = p_request_key;
  if found then  -- idempotent replay
    if w.user_id <> v_uid then perform private.raise_code('invalid_input', '{"field":"p_request_key"}'); end if;
    return query select w.id, w.status;
    return;
  end if;
  if p.locked_at is not null then perform private.raise_code('account_locked'); end if;
  if not exists (select 1 from public.kyc_profiles k where k.user_id = v_uid and k.status = 'verified') then
    perform private.raise_code('kyc_required');
  end if;
  select (value #>> '{}')::bigint into v_min from public.app_settings where key = 'min_withdraw_vnd';
  select (value #>> '{}')::bigint into v_cap from public.app_settings where key = 'withdraw_daily_cap_vnd';
  if p_amount is null or p_amount < coalesce(v_min, 50000) then
    perform private.raise_code('invalid_input', '{"field":"p_amount"}');
  end if;
  select * into b from public.bank_accounts x where x.id = p_bank_account_id and x.user_id = v_uid;
  if not found or p_request_key is null then
    perform private.raise_code('invalid_input', '{"field":"p_bank_account_id"}');
  end if;
  if p_pin_token is null or not private.consume_pin_token(v_uid, p_pin_token) then
    perform private.raise_code('pin_invalid');
  end if;
  if p.withdrawal_hold_until is not null and p.withdrawal_hold_until > now() then
    perform private.raise_code('hold_active', jsonb_build_object('until', p.withdrawal_hold_until));
  end if;
  if coalesce((select sum(x.amount) from public.withdrawals x
                where x.user_id = v_uid and x.status <> 'rejected' and x.created_at > now() - interval '24 hours'), 0)
     + p_amount > coalesce(v_cap, 5000000) then
    perform private.raise_code('daily_cap');
  end if;
  insert into public.withdrawals (request_key, user_id, amount, bank_account_id, bank_bin, account_number, account_name, risk_level)
  values (p_request_key, v_uid, p_amount, b.id, b.bank_bin, b.account_number, b.account_name,
    case when exists (select 1 from public.fraud_flags f where f.user_id = v_uid and f.status = 'open') then 'high'
         when p.created_at > now() - interval '7 days' then 'medium' else 'low' end)
  returning * into w;
  insert into public.wallet_ledger (user_id, entry_type, amount_vnd, withdrawal_id, idempotency_key, note)
  values (v_uid, 'withdrawal_debit', -p_amount, w.id, 'wd:' || w.id, 'withdrawal');  -- raises insufficient_balance
  return query select w.id, w.status;
end $$;

