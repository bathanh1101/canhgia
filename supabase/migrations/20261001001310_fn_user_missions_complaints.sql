-- User engagement fns part 2: missions, link share, notifications, missing-order complaints.
-- progress of one mission kind for the week starting p_week (Monday, Asia/Ho_Chi_Minh)
create function private.mission_count(p_uid uuid, p_kind text, p_week date) returns int
language sql stable security definer set search_path = pg_catalog, public as $$
  select case p_kind
    when 'orders_in_week' then (select count(*)::int from public.orders o
       where o.user_id = p_uid and o.credit_state in ('pending', 'credited')
         and coalesce(o.order_time, o.created_at) >= private.vn_ts(p_week)
         and coalesce(o.order_time, o.created_at) < private.vn_ts(p_week + 7))
    when 'share_link' then (select count(*)::int from public.clicks c
       where c.user_id = p_uid and c.shared_at >= private.vn_ts(p_week) and c.shared_at < private.vn_ts(p_week + 7))
    when 'invite_signup' then (select count(*)::int from public.referrals r
       where r.referrer_id = p_uid and r.created_at >= private.vn_ts(p_week) and r.created_at < private.vn_ts(p_week + 7))
    else 0 end
$$;

create function public.get_mission_progress()
returns table (code text, title text, progress int, target int, reward_kind text, reward_amount int, claimed boolean)
language plpgsql stable security definer set search_path = pg_catalog, public as $$
declare
  v_uid uuid := private.require_uid();
  v_week date := date_trunc('week', private.vn_today())::date;
begin
  return query
    select m.code, m.title, least(private.mission_count(v_uid, m.kind, v_week), m.target), m.target, m.reward_kind,
           m.reward_amount,
           exists (select 1 from public.mission_claims c where c.user_id = v_uid and c.code = m.code and c.week_start = v_week)
      from public.missions m where m.is_active order by m.sort, m.code;
end $$;

-- vnd reward -> mission_bonus (held like other credits); coins -> coin_ledger; invite_signup is paid via referral
create function public.claim_mission(p_code text) returns int
language plpgsql security definer set search_path = pg_catalog, public as $$
declare
  v_uid uuid := private.require_uid();
  v_week date := date_trunc('week', private.vn_today())::date;
  m public.missions;
  n int;
begin
  if (select locked_at from public.profiles where id = v_uid) is not null then
    perform private.raise_code('account_locked');
  end if;
  select * into m from public.missions where code = p_code and is_active;
  if not found then perform private.raise_code('invalid_input', '{"field":"p_code"}'); end if;
  if m.kind = 'invite_signup' then perform private.raise_code('invalid_input', '{"reason":"display_only"}'); end if;
  if private.mission_count(v_uid, m.kind, v_week) < m.target then
    perform private.raise_code('invalid_input', '{"reason":"not_complete"}');
  end if;
  insert into public.mission_claims (user_id, code, week_start, reward_amount) values (v_uid, m.code, v_week, m.reward_amount)
  on conflict do nothing;
  get diagnostics n = row_count;
  if n = 0 then perform private.raise_code('invalid_input', '{"reason":"already_claimed"}'); end if;
  if m.reward_amount > 0 then
    if m.reward_kind = 'vnd' then
      insert into public.wallet_ledger (user_id, entry_type, amount_vnd, idempotency_key, available_at, note)
      values (v_uid, 'mission_bonus', m.reward_amount, 'ms:' || v_uid || ':' || m.code || ':' || v_week,
              now() + interval '30 days', m.title);
    else
      insert into public.coin_ledger (user_id, amount, reason, idempotency_key)
      values (v_uid, m.reward_amount, 'mission:' || m.code, 'ms:' || v_uid || ':' || m.code || ':' || v_week);
    end if;
  end if;
  return m.reward_amount;
end $$;

create function public.record_link_share(p_click_id bigint) returns void
language plpgsql security definer set search_path = pg_catalog, public as $$
begin
  update public.clicks set shared_at = coalesce(shared_at, now()) where id = p_click_id and user_id = private.require_uid();
  if not found then perform private.raise_code('invalid_input', '{"field":"p_click_id"}'); end if;
end $$;

create function public.mark_notifications_read(p_ids bigint[] default null) returns int
language plpgsql security definer set search_path = pg_catalog, public as $$
declare
  n int;
begin
  update public.notifications set read_at = now()
   where user_id = private.require_uid() and read_at is null and (p_ids is null or id = any(p_ids));
  get diagnostics n = row_count;
  return n;
end $$;

-- purchased 1..60 days ago; images under <uid>/ in bucket complaints; <= 5 open reports per user
create function public.submit_missing_order(p_merchant_id text, p_order_code text, p_purchased_on date, p_value bigint,
  p_image_paths text[]) returns text
language plpgsql security definer set search_path = pg_catalog, public as $$
declare
  v_uid uuid := private.require_uid();
  v_path text;
  v_code text;
begin
  if (select locked_at from public.profiles where id = v_uid) is not null then
    perform private.raise_code('account_locked');
  end if;
  if not exists (select 1 from public.merchants where id = p_merchant_id and is_active) then
    perform private.raise_code('invalid_input', '{"field":"p_merchant_id"}');
  end if;
  if p_order_code is null or length(upper(regexp_replace(p_order_code, '[^A-Za-z0-9]', '', 'g'))) not between 4 and 40 then
    perform private.raise_code('invalid_input', '{"field":"p_order_code"}');
  end if;
  if p_purchased_on is null or p_purchased_on > private.vn_today() - 1 or p_purchased_on < private.vn_today() - 60 then
    perform private.raise_code('invalid_input', '{"field":"p_purchased_on"}');
  end if;
  if p_value is null or p_value <= 0 or p_value > 1000000000 then
    perform private.raise_code('invalid_input', '{"field":"p_value"}');
  end if;
  if p_image_paths is null or cardinality(p_image_paths) not between 1 and 5 then
    perform private.raise_code('invalid_input', '{"field":"p_image_paths"}');
  end if;
  foreach v_path in array p_image_paths loop
    if v_path is null or split_part(v_path, '/', 1) <> v_uid::text
       or not exists (select 1 from storage.objects o where o.bucket_id = 'complaints' and o.name = v_path) then
      perform private.raise_code('invalid_input', '{"field":"p_image_paths"}');
    end if;
  end loop;
  perform pg_advisory_xact_lock(hashtextextended('mor:' || v_uid, 0));
  if (select count(*) from public.missing_order_reports r
       where r.user_id = v_uid and r.status in ('pending', 'reviewing')) >= 5 then
    perform private.raise_code('rate_limited');
  end if;
  begin
    insert into public.missing_order_reports (user_id, merchant_id, order_code, purchased_on, order_value_vnd, image_paths)
    values (v_uid, p_merchant_id, btrim(p_order_code), p_purchased_on, p_value, p_image_paths)
    returning public_code into v_code;
  exception when unique_violation then
    perform private.raise_code('invalid_input', '{"reason":"duplicate_order_code"}');
  end;
  return v_code;
end $$;
