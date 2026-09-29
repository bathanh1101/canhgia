-- Phase 02a: default-privilege revokes FIRST (Sec-1), extensions, enums, private schema, helpers.
alter default privileges revoke execute on functions from public;
alter default privileges in schema public revoke execute on functions from public, anon, authenticated;

create extension if not exists pgcrypto with schema extensions;
create extension if not exists unaccent with schema extensions;
create extension if not exists pg_cron;
create extension if not exists pg_net with schema extensions;

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create type public.order_source as enum ('accesstrade', 'manual');
create type public.credit_state as enum ('none', 'pending', 'credited', 'cancelled', 'reversed');
create type public.ledger_entry_type as enum (
  'cashback_credit', 'cashback_reversal', 'withdrawal_debit', 'withdrawal_refund', 'referral_bonus',
  'referral_reversal', 'mission_bonus', 'manual_credit', 'manual_reversal', 'admin_adjustment');
create type public.withdrawal_status as enum ('pending', 'processing', 'paid', 'rejected');
create type public.kyc_status as enum ('pending', 'verified', 'rejected');
create type public.notification_type as enum ('order', 'wallet', 'promo', 'referral', 'system');
create type public.fraud_type as enum (
  'multi_account_device', 'shared_identity', 'shared_bank_account', 'abnormal_clicks', 'self_referral',
  'order_claim_conflict', 'negative_balance_risk');
create type public.flag_status as enum ('open', 'dismissed', 'actioned');
create type public.referral_status as enum ('pending', 'qualified', 'rewarded', 'held', 'void');
create type public.click_source as enum ('app', 'extension');
create type public.click_status as enum ('pending', 'ok', 'failed');

-- lower-case, accent-free, single-spaced (đ folded by unaccent)
create function private.norm_vn(p text) returns text
language sql stable set search_path = pg_catalog, extensions as $$
  select nullif(btrim(regexp_replace(lower(extensions.unaccent(coalesce(p, ''))), '\s+', ' ', 'g')), '')
$$;

-- error vocabulary: message = code, detail = json (PostgREST surfaces both)
create function private.raise_code(p_code text, p_detail jsonb default '{}'::jsonb) returns void
language plpgsql immutable set search_path = pg_catalog as $$
begin
  raise exception using message = p_code, detail = p_detail::text;
end $$;
