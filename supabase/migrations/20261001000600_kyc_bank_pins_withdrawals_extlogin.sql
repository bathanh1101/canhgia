-- KYC, bank accounts, PIN (private), withdrawals, extension QR-pair login.
create table public.kyc_profiles (
  user_id uuid primary key references public.profiles (id) on delete restrict,
  full_name text not null,
  full_name_norm text not null,
  id_number_last4 text not null,
  id_number_hmac text not null,
  front_path text not null,
  back_path text not null,
  status public.kyc_status not null default 'pending',
  reject_reason text,
  submitted_at timestamptz not null default now(),
  reviewed_by uuid,
  reviewed_at timestamptz
);
create index on public.kyc_profiles (id_number_hmac);

create table public.bank_accounts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete restrict,
  bank_bin text not null,
  account_number text not null,
  account_name text not null,
  account_name_norm text not null,
  is_default boolean not null default false,
  holder_name_verified boolean not null default false,
  created_at timestamptz not null default now(),
  unique (user_id, bank_bin, account_number)
);
create index on public.bank_accounts (bank_bin, account_number);

create table private.user_pins (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  pin_hash text not null,
  failed_attempts int not null default 0,
  locked_until timestamptz,
  updated_at timestamptz not null default now()
);

create table private.pin_tokens (
  token uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  expires_at timestamptz not null default now() + interval '60 seconds',
  used_at timestamptz
);

create table public.withdrawals (
  id uuid primary key default gen_random_uuid(),
  request_key uuid not null unique,
  user_id uuid not null references public.profiles (id) on delete restrict,
  amount bigint not null check (amount > 0),
  bank_account_id uuid references public.bank_accounts (id) on delete restrict,
  bank_bin text not null,
  account_number text not null,
  account_name text not null,
  status public.withdrawal_status not null default 'pending',
  risk_level text not null default 'low',
  claimed_by uuid,
  claimed_at timestamptz,
  paid_by uuid,
  paid_at timestamptz,
  transfer_ref text,
  reject_reason text,
  created_at timestamptz not null default now()
);
create index on public.withdrawals (user_id, created_at desc);
create index on public.withdrawals (status, created_at);
alter table public.wallet_ledger add foreign key (withdrawal_id) references public.withdrawals (id) on delete restrict;

create table public.extension_login_codes (
  code uuid primary key default gen_random_uuid(),
  secret_hash text not null,
  requester_ip inet,
  user_agent text,
  user_id uuid references public.profiles (id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'approved', 'consumed')),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '2 minutes'
);
create index on public.extension_login_codes (requester_ip, created_at);
