-- RLS everywhere; users read own rows only; writes via definer fns. Realtime + private buckets.
do $$
declare
  t text;
begin
  for t in select tablename from pg_tables where schemaname = 'public' loop
    execute format('alter table public.%I enable row level security', t);
  end loop;
end $$;

revoke all on all tables in schema public from anon, authenticated;
grant select on all tables in schema public to authenticated;
grant select on public.merchants, public.vip_tiers, public.offers, public.product_groups,
  public.price_snapshots, public.vouchers to anon;
grant insert, update, delete on public.push_tokens to authenticated;

-- Sec-9: owners never see fraud tier, admin ids, commission internals. Column grants (RLS is row-level only);
-- admins read the full rows through the admin_* views. wallets/notifications stay fully selectable (Realtime).
do $$
declare
  r record;
begin
  for r in select * from (values
    ('withdrawals', array['risk_level', 'claimed_by', 'paid_by']),
    ('wallet_ledger', array['created_by', 'held_remaining']),
    ('orders', array['commission_vnd', 'user_share_bps', 'vip_bonus_bps'])) v(t, x)
  loop
    execute format('revoke select on public.%I from authenticated', r.t);
    execute format('grant select (%s) on public.%I to authenticated',
      (select string_agg(quote_ident(a.attname), ', ') from pg_attribute a
        where a.attrelid = format('public.%I', r.t)::regclass and a.attnum > 0 and not a.attisdropped
          and a.attname <> all (r.x)), r.t);
  end loop;
end $$;

create view public.admin_withdrawals as select * from public.withdrawals where public.is_admin();
create view public.admin_orders as select * from public.orders where public.is_admin();
revoke all on public.admin_withdrawals, public.admin_orders from anon, authenticated;
grant select on public.admin_withdrawals, public.admin_orders to authenticated;

-- own-row SELECT (or admin)
do $$
declare
  r record;
begin
  for r in select * from (values
    ('profiles', 'id'), ('wallets', 'user_id'), ('wallet_ledger', 'user_id'), ('orders', 'user_id'),
    ('clicks', 'user_id'), ('notifications', 'user_id'), ('withdrawals', 'user_id'),
    ('bank_accounts', 'user_id'), ('kyc_profiles', 'user_id'), ('referrals', 'referrer_id'),
    ('user_devices', 'user_id'), ('push_tokens', 'user_id')) v(t, c)
  loop
    execute format('create policy own_select on public.%I for select to authenticated
                    using (%I = (select auth.uid()) or (select public.is_admin()))', r.t, r.c);
  end loop;
  -- public reference data
  for r in select unnest(array['merchants', 'vip_tiers', 'offers', 'product_groups', 'price_snapshots', 'vouchers']) t
  loop
    execute format('create policy public_select on public.%I for select to anon, authenticated using (true)', r.t);
  end loop;
  -- admin-only
  for r in select unnest(array['user_risk', 'order_raw', 'cashback_rules', 'campaign_commissions', 'fraud_flags',
      'admin_audit_log', 'app_settings', 'sync_state', 'sync_errors', 'admins', 'at_rate_bucket']) t
  loop
    execute format('create policy admin_select on public.%I for select to authenticated
                    using ((select public.is_admin()))', r.t);
  end loop;
end $$;

create policy own_write_ins on public.push_tokens for insert to authenticated with check (user_id = (select auth.uid()));
create policy own_write_upd on public.push_tokens for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy own_write_del on public.push_tokens for delete to authenticated using (user_id = (select auth.uid()));

alter publication supabase_realtime add table public.wallets, public.orders, public.notifications, public.withdrawals;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('kyc', 'kyc', false, 5242880, array['image/jpeg', 'image/png']),
  ('complaints', 'complaints', false, 5242880, array['image/jpeg', 'image/png'])
on conflict (id) do nothing;

create policy own_prefix_insert on storage.objects for insert to authenticated
  with check (bucket_id in ('kyc', 'complaints') and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy own_prefix_select on storage.objects for select to authenticated
  using (bucket_id in ('kyc', 'complaints')
         and ((storage.foldername(name))[1] = (select auth.uid())::text or (select public.is_admin())));
