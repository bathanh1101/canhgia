-- Catalog + commission reference tables (rows are 02b reference data / 03 svc upserts).
create table public.merchants (
  id text primary key,
  name text not null,
  badge_letter text,
  domains text[] not null default '{}',
  at_campaign_id text,
  link_api text not null default 'campaign_default' check (link_api in ('product_link', 'tiktok_shop', 'campaign_default')),
  max_user_rate_bps int,
  datafeed_enabled boolean not null default false,
  extension_enabled boolean not null default false,
  activation_hours int not null default 24,
  hold_days int not null default 30 check (hold_days >= 0),
  is_active boolean not null default true,
  sort int not null default 0
);

create table public.campaign_commissions (
  merchant_id text not null references public.merchants (id),
  category_key text not null default '',
  commission_rate_bps int not null,
  updated_at timestamptz not null default now(),
  primary key (merchant_id, category_key)
);

-- user_share_bps of the COMMISSION; null merchant/category = default row
create table public.cashback_rules (
  id bigint generated always as identity primary key,
  merchant_id text references public.merchants (id),
  category_key text,
  user_share_bps int not null check (user_share_bps between 0 and 10000),
  unique nulls not distinct (merchant_id, category_key)
);

create table public.vip_tiers (
  code text primary key,
  name text,
  min_gmv_12m_vnd bigint not null default 0,
  bonus_bps int not null default 0 check (bonus_bps between 0 and 10000)
);
alter table public.profiles add foreign key (vip_tier_code) references public.vip_tiers (code);

create table public.product_groups (
  id bigint generated always as identity primary key,
  group_key text not null unique,
  created_at timestamptz not null default now()
);

create table public.offers (
  id bigint generated always as identity primary key,
  merchant_id text not null references public.merchants (id),
  external_product_id text not null,
  sku text,
  brand text,
  name text not null,
  name_norm text,
  fts tsvector,
  url text,
  image_url text,
  category_key text,
  price bigint,
  list_price bigint,
  shop_name text,
  cashback_eligible boolean not null default true,
  product_group_id bigint references public.product_groups (id),
  updated_at timestamptz not null default now(),
  unique (merchant_id, external_product_id)
);
create index on public.offers using gin (fts);
create index on public.offers (product_group_id);

create table public.price_snapshots (
  offer_id bigint not null references public.offers (id) on delete cascade,
  day date not null,
  price bigint not null,
  primary key (offer_id, day)
);

create table public.vouchers (
  id bigint generated always as identity primary key,
  merchant_id text not null references public.merchants (id),
  external_id text not null,
  code text,
  title text,
  description text,
  discount_text text,
  url text,
  starts_at timestamptz,
  ends_at timestamptz,
  updated_at timestamptz not null default now(),
  unique (merchant_id, external_id)
);
