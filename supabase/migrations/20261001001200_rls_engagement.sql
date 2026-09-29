-- RLS for 02b tables. Own-row SELECT; own-row CRUD only on saved_vouchers / watchlist_items. Writes elsewhere via definer fns.
do $$
declare
  r record;
begin
  for r in select unnest(array['user_activity_days', 'missions', 'mission_claims', 'daily_checkins', 'coin_ledger',
      'saved_vouchers', 'watchlist_items', 'missing_order_reports', 'product_key_rules', 'banks']) t
  loop
    execute format('alter table public.%I enable row level security', r.t);
  end loop;
  for r in select * from (values
    ('user_activity_days'), ('mission_claims'), ('daily_checkins'), ('coin_ledger'), ('saved_vouchers'),
    ('watchlist_items'), ('missing_order_reports')) v(t)
  loop
    execute format('create policy own_select on public.%I for select to authenticated
                    using (user_id = (select auth.uid()) or (select public.is_admin()))', r.t);
  end loop;
end $$;

create policy public_select on public.missions for select to anon, authenticated using (true);
create policy public_select on public.banks for select to anon, authenticated using (true);
create policy admin_select on public.product_key_rules for select to authenticated using ((select public.is_admin()));

create policy own_write_ins on public.saved_vouchers for insert to authenticated with check (user_id = (select auth.uid()));
create policy own_write_del on public.saved_vouchers for delete to authenticated using (user_id = (select auth.uid()));
create policy own_write_ins on public.watchlist_items for insert to authenticated with check (user_id = (select auth.uid()));
create policy own_write_upd on public.watchlist_items for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy own_write_del on public.watchlist_items for delete to authenticated using (user_id = (select auth.uid()));
