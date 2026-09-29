-- Admin reports. Single SQL source for KPIs. Days are Asia/Ho_Chi_Minh; ranges are inclusive [p_from, p_to].
-- Order-side numbers use order_time (created_at when absent); paid_to_users nets these ledger types + admin_adjustment.
create function private.paid_types() returns public.ledger_entry_type[]
language sql immutable set search_path = pg_catalog as $$
  select array['cashback_credit', 'cashback_reversal', 'referral_bonus', 'referral_reversal', 'mission_bonus',
               'manual_credit', 'manual_reversal', 'admin_adjustment']::public.ledger_entry_type[]
$$;

create function public.admin_overview(p_from date, p_to date)
returns table (gmv_vnd bigint, commission_vnd bigint, paid_to_users_vnd bigint, net_vnd bigint,
  pending_commission_vnd bigint, unmatched_count int, unmatched_ratio numeric, sync_errors_24h int)
language plpgsql security definer set search_path = pg_catalog, public as $$
#variable_conflict use_column
declare
  v_from timestamptz;
  v_to timestamptz;
  v_total int;
begin
  perform private.admin_gate('overview', p_from || '..' || p_to);
  if p_from is null or p_to is null or p_from > p_to then perform private.raise_code('invalid_input', '{"field":"p_from"}'); end if;
  v_from := private.vn_ts(p_from); v_to := private.vn_ts(p_to + 1);
  select coalesce(sum(o.value_vnd) filter (where o.credit_state in ('pending', 'credited')), 0),
         coalesce(sum(o.commission_vnd) filter (where o.credit_state = 'credited'), 0),
         coalesce(sum(o.commission_vnd) filter (where o.credit_state = 'pending'), 0),
         count(*) filter (where o.user_id is null), count(*)
    into gmv_vnd, commission_vnd, pending_commission_vnd, unmatched_count, v_total
    from public.orders o where coalesce(o.order_time, o.created_at) >= v_from and coalesce(o.order_time, o.created_at) < v_to;
  select coalesce(sum(l.amount_vnd), 0) into paid_to_users_vnd from public.wallet_ledger l
   where l.entry_type = any (private.paid_types()) and l.created_at >= v_from and l.created_at < v_to;
  net_vnd := commission_vnd - paid_to_users_vnd;
  unmatched_ratio := case when v_total = 0 then 0 else round(unmatched_count::numeric / v_total, 4) end;
  select count(*)::int into sync_errors_24h from public.sync_errors e where e.created_at > now() - interval '24 hours';
  return next;
end $$;

create function public.admin_monthly_series(p_months int default 12)
returns table (month date, commission_vnd bigint, paid_vnd bigint, net_vnd bigint)
language plpgsql security definer set search_path = pg_catalog, public as $$
#variable_conflict use_column
declare
  v_n int := greatest(1, least(coalesce(p_months, 12), 36));
  v_first date := (date_trunc('month', private.vn_today()) - make_interval(months => v_n - 1))::date;
begin
  perform private.admin_gate('monthly_series', v_n::text);
  return query
    with m as (select d::date mon from generate_series(v_first, v_first + make_interval(months => v_n - 1), interval '1 month') d),
    c as (select date_trunc('month', coalesce(o.order_time, o.created_at) at time zone 'Asia/Ho_Chi_Minh')::date mon,
                 sum(o.commission_vnd) v from public.orders o where o.credit_state = 'credited' group by 1),
    p as (select date_trunc('month', l.created_at at time zone 'Asia/Ho_Chi_Minh')::date mon, sum(l.amount_vnd) v
            from public.wallet_ledger l where l.entry_type = any (private.paid_types()) group by 1)
    select m.mon, coalesce(c.v, 0)::bigint, coalesce(p.v, 0)::bigint, (coalesce(c.v, 0) - coalesce(p.v, 0))::bigint
      from m left join c on c.mon = m.mon left join p on p.mon = m.mon order by m.mon;
end $$;

create function public.admin_merchant_mix(p_from date, p_to date) returns table (merchant_id text, commission_vnd bigint, share numeric)
language plpgsql security definer set search_path = pg_catalog, public as $$
#variable_conflict use_column
begin
  perform private.admin_gate('merchant_mix', p_from || '..' || p_to);
  if p_from is null or p_to is null or p_from > p_to then perform private.raise_code('invalid_input', '{"field":"p_from"}'); end if;
  return query
    with s as (select o.merchant_id, sum(o.commission_vnd)::bigint v from public.orders o
                where o.credit_state = 'credited' and coalesce(o.order_time, o.created_at) >= private.vn_ts(p_from)
                  and coalesce(o.order_time, o.created_at) < private.vn_ts(p_to + 1) group by 1)
    select s.merchant_id, s.v, case when sum(s.v) over () = 0 then 0 else round(s.v::numeric / sum(s.v) over (), 4) end
      from s order by s.v desc, s.merchant_id;
end $$;

-- d30_retention: share of users who signed up 30-60 days ago and were active again >= 30 days after signup
create function public.admin_user_stats(p_days int default 30) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public as $$
declare
  v_days int := greatest(1, least(coalesce(p_days, 30), 365));
  v_cohort int;
  v_kept int;
begin
  perform private.admin_gate('user_stats', v_days::text);
  select count(*), count(*) filter (where exists (select 1 from public.user_activity_days a
           where a.user_id = p.id and a.day >= (p.created_at at time zone 'Asia/Ho_Chi_Minh')::date + 30))
    into v_cohort, v_kept from public.profiles p
   where p.created_at >= private.vn_ts(private.vn_today() - 60) and p.created_at < private.vn_ts(private.vn_today() - 29);
  return jsonb_build_object(
    'new_users_month', (select count(*) from public.profiles p
                         where p.created_at >= private.vn_ts(date_trunc('month', private.vn_today())::date)),
    'd30_retention', case when v_cohort = 0 then 0 else round(v_kept::numeric / v_cohort, 4) end,
    'dau', coalesce((select jsonb_agg(jsonb_build_object('day', d.day, 'count', d.n) order by d.day)
                       from (select a.day, count(*) n from public.user_activity_days a
                              where a.day > private.vn_today() - v_days group by a.day) d), '[]'::jsonb));
end $$;

create function public.admin_top_users(p_limit int default 10)
returns table (user_id uuid, email text, gmv_vnd bigint, cashback_vnd bigint, orders int)
language plpgsql security definer set search_path = pg_catalog, public as $$
#variable_conflict use_column
begin
  perform private.admin_gate('top_users', p_limit::text);
  return query
    select o.user_id, p.email, sum(o.value_vnd)::bigint, sum(o.user_cashback_vnd)::bigint, count(*)::int
      from public.orders o join public.profiles p on p.id = o.user_id
     where o.credit_state = 'credited' group by o.user_id, p.email
     order by 3 desc, 1 limit greatest(1, least(coalesce(p_limit, 10), 100));
end $$;
