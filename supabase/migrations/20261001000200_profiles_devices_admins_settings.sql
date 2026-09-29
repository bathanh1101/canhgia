-- Users, devices, admins, settings. Writes only via definer fns.
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  short_id bigint generated always as identity (start with 1000) unique,
  display_name text,
  email text,
  referral_code text not null unique default upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8)),
  referred_by uuid references public.profiles (id),
  vip_tier_code text,
  coin_balance bigint not null default 0 check (coin_balance >= 0),
  has_pin boolean not null default false,
  locked_at timestamptz,
  notification_prefs jsonb not null default '{"order":true,"wallet":true,"promo":true,"referral":true}',
  onboarded_at timestamptz,
  withdrawal_hold_until timestamptz,
  created_at timestamptz not null default now()
);

create table public.user_risk (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  risk_score int not null default 0,
  level text not null default 'low',
  lock_reason text,
  updated_at timestamptz not null default now()
);

create table public.user_devices (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles (id) on delete cascade,
  device_hash text not null,
  platform text not null,
  model text,
  last_seen_at timestamptz not null default now(),
  unique (user_id, device_hash)
);
create index on public.user_devices (device_hash);

create table public.push_tokens (
  token text primary key,
  user_id uuid not null references public.profiles (id) on delete cascade,
  platform text not null,
  created_at timestamptz not null default now()
);
create index on public.push_tokens (user_id);

create table public.admins (
  user_id uuid primary key references public.profiles (id) on delete restrict,
  created_by uuid references public.profiles (id),
  created_at timestamptz not null default now()
);

create table public.admin_audit_log (
  id bigint generated always as identity primary key,
  admin_id uuid,
  action text not null,
  target text,
  detail jsonb not null default '{}',
  created_at timestamptz not null default now()
);

create table public.app_settings (
  key text primary key,
  value jsonb
);
insert into public.app_settings (key, value) values
  ('min_withdraw_vnd', '50000'), ('withdraw_daily_cap_vnd', '5000000'), ('referral_bonus_vnd', '30000'),
  ('click_limit_per_hour', '30'), ('withdraw_eta_text', '"1-2 ngày làm việc"'), ('landing_stats', 'null'),
  ('auto_payout_enabled', 'false'), ('auto_payout_limit_vnd', '0'); -- auto_payout_*: STUB, no consumer

-- Sec-6: authority = admins row AND aal2 (TOTP) session, never a stale JWT claim
create function public.is_admin() returns boolean
language sql stable security definer set search_path = pg_catalog, public, extensions as $$
  select exists (select 1 from public.admins a where a.user_id = auth.uid())
     and coalesce(auth.jwt() ->> 'aal', '') = 'aal2'
$$;
