-- Clicks, orders (AccessTrade + manual), raw payloads, sync bookkeeping, AT rate buckets.
create table public.clicks (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles (id) on delete restrict,
  merchant_id text not null references public.merchants (id),
  origin_url text,
  resolved_url text,
  offer_id bigint references public.offers (id),
  utm_content text,
  aff_link text,
  short_link text,
  status public.click_status not null default 'pending',
  source public.click_source not null default 'app',
  device_hash text,
  shared_at timestamptz,
  created_at timestamptz not null default now()
);
create index on public.clicks (user_id, created_at desc);

create table public.orders (
  id uuid primary key default gen_random_uuid(),
  source public.order_source not null default 'accesstrade',
  conversion_id bigint unique,
  merchant_id text not null references public.merchants (id),
  transaction_id text,
  transaction_id_norm text generated always as (upper(regexp_replace(transaction_id, '[^A-Za-z0-9]', '', 'g'))) stored,
  product_id text,
  product_name text,
  category_key text,
  product_price bigint,
  product_quantity int,
  value_vnd bigint not null default 0,
  commission_vnd bigint not null default 0,
  at_status int,
  is_confirmed int not null default 0,
  click_time timestamptz,
  order_time timestamptz,
  update_time timestamptz,
  confirmed_time timestamptz,
  withdrawable_at timestamptz,
  utm_content text,
  user_id uuid references public.profiles (id) on delete restrict,
  click_id bigint references public.clicks (id),
  matched_by text,
  user_share_bps int,
  vip_bonus_bps int,
  user_cashback_vnd bigint not null default 0,
  credit_state public.credit_state not null default 'none',
  created_at timestamptz not null default now()
);
create unique index orders_manual_txn_uq on public.orders (merchant_id, transaction_id_norm) where source = 'manual';
create index on public.orders (merchant_id, transaction_id_norm);
create index on public.orders (user_id, created_at desc);

create table public.order_raw (
  order_id uuid primary key references public.orders (id) on delete cascade,
  raw jsonb not null
);

create table public.sync_state (
  job text primary key,
  cursor jsonb,
  last_success_at timestamptz,
  last_error text,
  locked_until timestamptz
);

create table public.sync_errors (
  id bigint generated always as identity primary key,
  job text not null,
  conversion_id bigint,
  raw jsonb,
  error text,
  created_at timestamptz not null default now()
);

create table public.at_rate_bucket (
  bucket text primary key,
  tokens numeric not null,
  capacity int not null,
  refill_per_min numeric not null,
  refilled_at timestamptz not null default now()
);
insert into public.at_rate_bucket (bucket, tokens, capacity, refill_per_min) values
  ('transactions', 5, 5, 10), ('product_link', 5, 5, 10), ('datafeeds', 5, 5, 10), ('catalog', 5, 5, 10);  -- AT limit is 10/min: burst 5
