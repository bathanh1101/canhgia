-- User-callable engagement fns (authenticated). auth.uid() never comes from params.
create function private.vn_today() returns date
language sql stable set search_path = pg_catalog as $$
  select (now() at time zone 'Asia/Ho_Chi_Minh')::date
$$;

create function private.vn_ts(p_day date) returns timestamptz
language sql immutable set search_path = pg_catalog as $$
  select p_day::timestamp at time zone 'Asia/Ho_Chi_Minh'
$$;

create function public.touch_activity() returns void
language plpgsql security definer set search_path = pg_catalog, public as $$
begin
  insert into public.user_activity_days (user_id, day) values (private.require_uid(), private.vn_today())
  on conflict do nothing;
end $$;

create function public.complete_onboarding() returns void
language plpgsql security definer set search_path = pg_catalog, public as $$
begin
  update public.profiles set onboarded_at = coalesce(onboarded_at, now()) where id = private.require_uid();
end $$;

create function public.update_profile(p_display_name text, p_notification_prefs jsonb) returns void
language plpgsql security definer set search_path = pg_catalog, public as $$
declare
  v_uid uuid := private.require_uid();
  v_name text := btrim(p_display_name);
begin
  if p_display_name is not null and (v_name = '' or length(v_name) > 60) then
    perform private.raise_code('invalid_input', '{"field":"p_display_name"}');
  end if;
  if p_notification_prefs is not null and (
       jsonb_typeof(p_notification_prefs) <> 'object'
       or exists (select 1 from jsonb_each(p_notification_prefs) e
                   where e.key not in ('order', 'wallet', 'promo', 'referral') or jsonb_typeof(e.value) <> 'boolean')) then
    perform private.raise_code('invalid_input', '{"field":"p_notification_prefs"}');
  end if;
  update public.profiles set display_name = coalesce(v_name, display_name),
    notification_prefs = case when p_notification_prefs is null then notification_prefs
                              else notification_prefs || p_notification_prefs end
   where id = v_uid;
end $$;

-- once, <= 7 days after signup, not self, no loops
create function public.bind_referral(p_code text) returns void
language plpgsql security definer set search_path = pg_catalog, public as $$
declare
  v_uid uuid := private.require_uid();
  me public.profiles;
  ref public.profiles;
begin
  select * into me from public.profiles where id = v_uid for update;
  select * into ref from public.profiles where referral_code = upper(btrim(p_code));
  if not found or ref.id = v_uid then perform private.raise_code('code_invalid'); end if;
  if me.referred_by is not null then perform private.raise_code('code_invalid', '{"reason":"already_bound"}'); end if;
  if me.created_at < now() - interval '7 days' then perform private.raise_code('code_invalid', '{"reason":"expired"}'); end if;
  if ref.referred_by = v_uid then perform private.raise_code('code_invalid', '{"reason":"loop"}'); end if;
  update public.profiles set referred_by = ref.id where id = v_uid;
  insert into public.referrals (referrer_id, referee_id) values (ref.id, v_uid) on conflict (referee_id) do nothing;
end $$;

-- 50 xu per day, 500 xu on every 7th consecutive day; replay on the same day returns the stored row
create function public.daily_checkin() returns table (coins int, streak int)
language plpgsql security definer set search_path = pg_catalog, public as $$
declare
  v_uid uuid := private.require_uid();
  v_day date := private.vn_today();
  v_streak int;
  v_coins int;
  n int;
begin
  if (select locked_at from public.profiles where id = v_uid) is not null then
    perform private.raise_code('account_locked');
  end if;
  v_streak := coalesce((select c.streak from public.daily_checkins c where c.user_id = v_uid and c.day = v_day - 1), 0) + 1;
  v_coins := case when v_streak % 7 = 0 then 500 else 50 end;
  insert into public.daily_checkins (user_id, day, coins, streak) values (v_uid, v_day, v_coins, v_streak)
  on conflict do nothing;
  get diagnostics n = row_count;
  if n = 1 then
    insert into public.coin_ledger (user_id, amount, reason, idempotency_key)
    values (v_uid, v_coins, 'checkin', 'ci:' || v_uid || ':' || v_day);
  end if;
  return query select c.coins, c.streak from public.daily_checkins c where c.user_id = v_uid and c.day = v_day;
end $$;
