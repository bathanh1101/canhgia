-- Service fns: push outbox, held->available promotion, drift check, extension login, cron wrapper.
create function public.claim_push_batch(p_limit int)
returns table (id bigint, user_id uuid, type public.notification_type, title text, body text, data jsonb, tokens text[])
language sql security definer set search_path = pg_catalog, public as $$
  with c as (
    select n.id from public.notifications n join public.profiles p on p.id = n.user_id
     where n.push_sent_at is null and n.push_attempts < 3
       and (n.push_claimed_at is null or n.push_claimed_at < now() - interval '10 minutes')
       and (p.notification_prefs ->> n.type::text) is distinct from 'false'
     order by n.id limit greatest(p_limit, 0) for update of n skip locked),
  u as (
    update public.notifications n set push_claimed_at = now(), push_attempts = n.push_attempts + 1
      from c where n.id = c.id returning n.*)
  select u.id, u.user_id, u.type, u.title, u.body, u.data,
         coalesce((select array_agg(t.token) from public.push_tokens t where t.user_id = u.user_id), '{}')
    from u
$$;

create function public.mark_push_sent(p_ids bigint[]) returns void
language sql security definer set search_path = pg_catalog, public as $$
  update public.notifications set push_sent_at = now() where id = any(p_ids)
$$;

-- Moves each due held ledger row (its held_remaining) to available. Per-row savepoint: one bad row never stalls the run;
-- wallet lock first (same order as ledger_route), promoted_at rechecked under the row lock so overlapping runs are idempotent.
-- Returns ledger rows promoted.
create function public.promote_withdrawable() returns int
language plpgsql security definer set search_path = pg_catalog, public as $$
declare
  d record;
  v_amt bigint;
  n int := 0;
begin
  for d in
    select l.id, l.user_id from public.wallet_ledger l
     where l.amount_vnd > 0 and l.promoted_at is null and l.available_at <= now()
     order by l.user_id, l.id
  loop
    begin
      perform 1 from public.wallets w where w.user_id = d.user_id for update;
      select x.held_remaining into v_amt from public.wallet_ledger x where x.id = d.id and x.promoted_at is null for update;
      if not found then continue; end if;
      update public.wallet_ledger set promoted_at = now(), held_remaining = 0 where id = d.id;
      update public.wallets set held_vnd = held_vnd - v_amt, available_vnd = available_vnd + v_amt, updated_at = now()
       where user_id = d.user_id;
      if v_amt > 0 then
        perform private.notify(d.user_id, 'wallet', 'Tiền hoàn đã khả dụng', 'Bạn có thể rút số tiền này',
          jsonb_build_object('amount_vnd', v_amt));
      end if;
      n := n + 1;
    exception when others then
      raise warning 'promote_withdrawable: ledger % skipped: %', d.id, sqlerrm;
    end;
  end loop;
  return n;
end $$;

create function public.check_wallet_drift()
returns table (user_id uuid, field text, wallet_vnd bigint, ledger_vnd bigint)
language sql stable security definer set search_path = pg_catalog, public as $$
  with led as (
    select l.user_id, sum(l.amount_vnd) total,
           sum(case when l.entry_type in ('cashback_credit', 'cashback_reversal', 'referral_bonus', 'referral_reversal',
               'mission_bonus', 'manual_credit', 'manual_reversal') then l.amount_vnd else 0 end) earned
      from public.wallet_ledger l group by l.user_id),
  held as (select l.user_id, sum(l.held_remaining) h from public.wallet_ledger l where l.held_remaining > 0 group by l.user_id),
  pend as (select o.user_id, sum(o.user_cashback_vnd) p from public.orders o
            where o.credit_state = 'pending' and o.user_id is not null group by o.user_id),
  x as (
    select w.user_id, w.held_vnd + w.available_vnd wb, coalesce(led.total, 0) lb, w.held_vnd wh, coalesce(held.h, 0) lh,
           w.pending_vnd wp, coalesce(pend.p, 0) lp, w.total_earned_vnd we, coalesce(led.earned, 0) le
      from public.wallets w left join led on led.user_id = w.user_id left join held on held.user_id = w.user_id
      left join pend on pend.user_id = w.user_id)
  select x.user_id, f.field, f.w, f.l from x cross join lateral (values
    ('balance', x.wb, x.lb), ('held', x.wh, x.lh), ('pending', x.wp, x.lp), ('earned', x.we, x.le)) f(field, w, l)
   where f.w <> f.l
$$;

create function public.start_extension_login(p_secret_hash text, p_ip inet, p_user_agent text)
returns table (code uuid, expires_at timestamptz)
language plpgsql security definer set search_path = pg_catalog, public as $$
begin
  if p_secret_hash is null or length(p_secret_hash) < 32 then
    perform private.raise_code('invalid_input', '{"field":"p_secret_hash"}');
  end if;
  if p_ip is null then
    perform private.raise_code('invalid_input', '{"field":"p_ip"}');
  end if;
  perform pg_advisory_xact_lock(hashtext(p_ip::text));  -- serialises count-then-insert per IP
  if (select count(*) from public.extension_login_codes c
       where c.requester_ip = p_ip and c.created_at > now() - interval '10 minutes') >= 5 then
    perform private.raise_code('rate_limited');
  end if;
  delete from public.extension_login_codes c where c.created_at < now() - interval '1 day';
  return query insert into public.extension_login_codes (secret_hash, requester_ip, user_agent)
    values (p_secret_hash, p_ip, left(p_user_agent, 300)) returning extension_login_codes.code, extension_login_codes.expires_at;
end $$;

-- p_secret is hashed with sha256 hex and compared to secret_hash given at start
create function public.consume_extension_login(p_code uuid, p_secret text) returns uuid
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare
  c public.extension_login_codes;
begin
  select * into c from public.extension_login_codes x where x.code = p_code for update;
  if not found or c.expires_at < now() or c.status = 'consumed'
     or c.secret_hash <> encode(extensions.digest(coalesce(p_secret, ''), 'sha256'), 'hex') then
    perform private.raise_code('code_invalid');
  end if;
  if c.status = 'pending' then perform private.raise_code('code_pending'); end if;
  update public.extension_login_codes set status = 'consumed' where code = p_code;
  update public.profiles set withdrawal_hold_until = greatest(coalesce(withdrawal_hold_until, now()), now() + interval '24 hours')
   where id = c.user_id;
  return c.user_id;
end $$;

-- cron wrapper: missing Vault secrets -> record + no-op
create function private.invoke_edge(p_fn text, p_body jsonb) returns void
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare
  v_url text;
  v_secret text;
begin
  select decrypted_secret into v_url from vault.decrypted_secrets where name = 'project_url';
  select decrypted_secret into v_secret from vault.decrypted_secrets where name = 'cron_secret';
  if v_url is null or v_secret is null then
    insert into public.sync_state (job, last_error) values (p_fn, 'vault_missing')
    on conflict (job) do update set last_error = 'vault_missing';
    return;
  end if;
  perform net.http_post(url := v_url || '/functions/v1/' || p_fn,
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-cron-secret', v_secret),
    body := coalesce(p_body, '{}'::jsonb));
end $$;
