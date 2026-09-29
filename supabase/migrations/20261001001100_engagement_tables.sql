-- Phase 02b: engagement tables (activity, missions, check-ins, coins, saved/watchlist, complaints, grouping rules, banks).
create table public.user_activity_days (
  user_id uuid not null references public.profiles (id) on delete cascade,
  day date not null,
  primary key (user_id, day)
);
create index on public.user_activity_days (day);

create table public.missions (
  code text primary key,
  title text not null,
  kind text not null check (kind in ('orders_in_week', 'share_link', 'invite_signup')),
  target int not null check (target > 0),
  reward_kind text not null check (reward_kind in ('vnd', 'coins')),
  reward_amount int not null check (reward_amount >= 0),
  sort int not null default 0,
  is_active boolean not null default true
);

create table public.mission_claims (
  user_id uuid not null references public.profiles (id) on delete cascade,
  code text not null references public.missions (code),
  week_start date not null,
  reward_amount int not null,
  claimed_at timestamptz not null default now(),
  primary key (user_id, code, week_start)
);

create table public.daily_checkins (
  user_id uuid not null references public.profiles (id) on delete cascade,
  day date not null,
  coins int not null,
  streak int not null,
  primary key (user_id, day)
);

create table public.coin_ledger (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles (id) on delete cascade,
  amount int not null check (amount <> 0),
  reason text not null,
  idempotency_key text not null unique,
  created_at timestamptz not null default now()
);
create index on public.coin_ledger (user_id, created_at desc);

create function private.coin_apply() returns trigger
language plpgsql security definer set search_path = pg_catalog, public as $$
begin
  update public.profiles set coin_balance = coin_balance + new.amount where id = new.user_id;
  return new;
end $$;
create trigger coin_ledger_apply after insert on public.coin_ledger
  for each row execute function private.coin_apply();

create table public.saved_vouchers (
  user_id uuid not null references public.profiles (id) on delete cascade,
  voucher_id bigint not null references public.vouchers (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, voucher_id)
);

create table public.watchlist_items (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles (id) on delete cascade,
  product_group_id bigint not null references public.product_groups (id) on delete cascade,
  target_price_vnd bigint not null check (target_price_vnd > 0),
  last_notified_at timestamptz,
  created_at timestamptz not null default now(),
  unique (user_id, product_group_id)
);

create sequence public.missing_order_code_seq;
create table public.missing_order_reports (
  id bigint generated always as identity primary key,
  public_code text not null unique default 'KN-' || lpad(nextval('public.missing_order_code_seq')::text, 6, '0'),
  user_id uuid not null references public.profiles (id) on delete restrict,
  merchant_id text not null references public.merchants (id),
  order_code text not null,
  order_code_norm text generated always as (upper(regexp_replace(order_code, '[^A-Za-z0-9]', '', 'g'))) stored,
  purchased_on date not null,
  order_value_vnd bigint not null check (order_value_vnd > 0),
  image_paths text[] not null default '{}',
  status text not null default 'pending' check (status in ('pending', 'reviewing', 'approved', 'rejected')),
  first_approved_by uuid,
  first_approved_at timestamptz,
  first_approved_amount bigint,
  resolution_amount_vnd bigint,
  resolved_order_id uuid references public.orders (id),
  admin_note text,
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);
create unique index missing_order_reports_code_uq on public.missing_order_reports (merchant_id, order_code_norm)
  where order_code_norm is not null;
create index on public.missing_order_reports (user_id, created_at desc);
create index on public.missing_order_reports (status, created_at);

-- regex on offers.name_norm (lower-case, accent-free); exactly 1 capture group = model
create table public.product_key_rules (
  id bigint generated always as identity primary key,
  brand text not null,
  pattern text not null,
  priority int not null default 100,
  unique (brand, pattern)
);

create table public.banks (
  bin text primary key check (bin ~ '^\d{6}$'),
  code text not null,
  name text not null,
  is_enabled boolean not null default true,
  sort int not null default 0
);
