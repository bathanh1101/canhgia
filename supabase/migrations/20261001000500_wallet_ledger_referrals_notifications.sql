-- Wallet + immutable ledger with held/available routing, referrals, notifications, fraud flags.
create table public.wallets (
  user_id uuid primary key references public.profiles (id) on delete restrict,
  pending_vnd bigint not null default 0,
  held_vnd bigint not null default 0 check (held_vnd >= 0),
  available_vnd bigint not null default 0,
  total_earned_vnd bigint not null default 0,
  updated_at timestamptz not null default now()
);

create table public.referrals (
  id bigint generated always as identity primary key,
  referrer_id uuid not null references public.profiles (id),
  referee_id uuid not null unique references public.profiles (id),
  status public.referral_status not null default 'pending',
  qualified_order_id uuid references public.orders (id),
  bonus_vnd bigint not null default 0,
  created_at timestamptz not null default now()
);


create table public.wallet_ledger (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles (id) on delete restrict,
  entry_type public.ledger_entry_type not null,
  amount_vnd bigint not null check (amount_vnd <> 0),
  order_id uuid references public.orders (id) on delete restrict,
  withdrawal_id uuid,
  referral_id bigint references public.referrals (id) on delete restrict,
  idempotency_key text not null unique,
  available_at timestamptz,
  promoted_at timestamptz,
  note text,
  created_by uuid,
  created_at timestamptz not null default now()
);
create index on public.wallet_ledger (user_id, created_at desc);
create index on public.wallet_ledger (order_id);
create index wallet_ledger_held_idx on public.wallet_ledger (available_at) where promoted_at is null and amount_vnd > 0;

create table public.notifications (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles (id) on delete cascade,
  type public.notification_type not null,
  title text not null,
  body text,
  data jsonb not null default '{}',
  read_at timestamptz,
  push_claimed_at timestamptz,
  push_attempts int not null default 0,
  push_sent_at timestamptz,
  created_at timestamptz not null default now()
);
create index on public.notifications (user_id, created_at desc);

create table public.fraud_flags (
  id bigint generated always as identity primary key,
  user_id uuid references public.profiles (id) on delete cascade,
  type public.fraud_type not null,
  score int not null default 0,
  evidence jsonb not null default '{}',
  status public.flag_status not null default 'open',
  dedupe_key text not null unique,
  resolved_by uuid,
  resolved_at timestamptz,
  created_at timestamptz not null default now()
);

-- Key of a ledger row for held bookkeeping: order, referral, or itself.
create function private.ledger_key(p_order uuid, p_referral bigint, p_id bigint) returns text
language sql immutable as $$
  select coalesce('o' || p_order::text, 'r' || p_referral::text, 'l' || p_id::text)
$$;

-- Routing (same txn as the insert). Invariant: a key is wholly held or wholly available, so
-- held(key) = sum(amount of key) while any positive row of the key is un-promoted.
create function private.ledger_route() returns trigger
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare
  w public.wallets;
  v_held bigint := 0;
  v_from_held bigint := 0;
begin
  select * into w from public.wallets where user_id = new.user_id for update;
  if not found then
    raise exception 'wallet_missing';
  end if;

  if new.amount_vnd > 0 then
    if new.available_at is not null and new.available_at > now() then
      update public.wallets set held_vnd = held_vnd + new.amount_vnd where user_id = new.user_id;
    else
      new.promoted_at := now();
      update public.wallets set available_vnd = available_vnd + new.amount_vnd where user_id = new.user_id;
    end if;
  else
    new.promoted_at := now();
    if new.entry_type in ('cashback_reversal', 'manual_reversal', 'referral_reversal')
       and (new.order_id is not null or new.referral_id is not null) then
      select coalesce(sum(l.amount_vnd), 0) into v_held
        from public.wallet_ledger l
       where l.user_id = new.user_id
         and l.order_id is not distinct from new.order_id
         and l.referral_id is not distinct from new.referral_id
         and exists (select 1 from public.wallet_ledger p
                      where p.user_id = new.user_id and p.order_id is not distinct from new.order_id
                        and p.referral_id is not distinct from new.referral_id
                        and p.amount_vnd > 0 and p.promoted_at is null);
      v_from_held := least(-new.amount_vnd, greatest(v_held, 0));
    end if;
    update public.wallets
       set held_vnd = held_vnd - v_from_held,
           available_vnd = available_vnd + new.amount_vnd + v_from_held
     where user_id = new.user_id
     returning * into w;
    if w.available_vnd < 0 and new.entry_type <> 'admin_adjustment' then
      perform private.raise_code('insufficient_balance');
    end if;
  end if;

  update public.wallets
     set total_earned_vnd = total_earned_vnd + case when new.entry_type in
           ('cashback_credit', 'cashback_reversal', 'referral_bonus', 'referral_reversal',
            'mission_bonus', 'manual_credit', 'manual_reversal') then new.amount_vnd else 0 end,
         updated_at = now()
   where user_id = new.user_id;
  return new;
end $$;
create trigger wallet_ledger_route before insert on public.wallet_ledger
  for each row execute function private.ledger_route();

create function private.ledger_immutable() returns trigger
language plpgsql set search_path = pg_catalog as $$
begin
  if tg_op = 'DELETE' then
    raise exception 'ledger_immutable';
  end if;
  if (to_jsonb(new) - 'promoted_at') is distinct from (to_jsonb(old) - 'promoted_at')
     or old.promoted_at is not null then
    raise exception 'ledger_immutable';
  end if;
  return new;
end $$;
create trigger wallet_ledger_guard before update or delete on public.wallet_ledger
  for each row execute function private.ledger_immutable();

-- orders -> wallets.pending_vnd (old/new user deltas)
create function private.orders_pending() returns trigger
language plpgsql security definer set search_path = pg_catalog, public as $$
begin
  if tg_op <> 'INSERT' and old.user_id is not null and old.credit_state = 'pending' then
    update public.wallets set pending_vnd = pending_vnd - old.user_cashback_vnd, updated_at = now()
     where user_id = old.user_id;
  end if;
  if tg_op <> 'DELETE' and new.user_id is not null and new.credit_state = 'pending' then
    update public.wallets set pending_vnd = pending_vnd + new.user_cashback_vnd, updated_at = now()
     where user_id = new.user_id;
  end if;
  return null;
end $$;
create trigger orders_pending after insert or update of user_id, credit_state, user_cashback_vnd on public.orders
  for each row execute function private.orders_pending();

-- auth.users -> profile + wallet (+ referral from signup metadata)
create function private.handle_new_user() returns trigger
language plpgsql security definer set search_path = pg_catalog, public as $$
declare
  v_ref uuid;
begin
  select id into v_ref from public.profiles
   where referral_code = upper(new.raw_user_meta_data ->> 'referral_code');
  insert into public.profiles (id, email, display_name, referred_by)
  values (new.id, new.email,
          coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name', split_part(new.email, '@', 1)),
          v_ref);
  insert into public.wallets (user_id) values (new.id);
  if v_ref is not null then
    insert into public.referrals (referrer_id, referee_id) values (v_ref, new.id);
  end if;
  return new;
end $$;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function private.handle_new_user();
