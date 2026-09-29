-- Phase 03: 13 pg_cron jobs (UTC; ICT = UTC+7). Idempotent: cron.schedule() upserts by job name.
-- HTTP jobs go through private.invoke_edge(), which is a no-op that records last_error='vault_missing' when the Vault
-- secrets are absent (db reset, fresh env). Per environment, once (never in a migration; values are not committed):
--   select vault.create_secret('https://<project-ref>.supabase.co', 'project_url');
--   select vault.create_secret('<same value as the CRON_SECRET Edge secret>', 'cron_secret');

-- Same wrapper as phase 02a plus timeout_milliseconds: pg_net defaults to 5 s, sync jobs run up to ~60 s budget + retries.
create or replace function private.invoke_edge(p_fn text, p_body jsonb) returns void
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
    body := coalesce(p_body, '{}'::jsonb),
    timeout_milliseconds := 150000);
end $$;

select cron.schedule('tx-recent', '*/20 * * * *', $c$select private.invoke_edge('sync-transactions', '{"window":"recent"}')$c$);
select cron.schedule('tx-older', '10 */6 * * *', $c$select private.invoke_edge('sync-transactions', '{"window":"older"}')$c$);
-- returns immediately once every datafeed merchant has been backfilled
select cron.schedule('datafeeds-backfill', '*/10 * * * *', $c$select private.invoke_edge('sync-datafeeds', '{"mode":"backfill"}')$c$);
select cron.schedule('datafeeds-delta', '*/10 19-22 * * *', $c$select private.invoke_edge('sync-datafeeds', '{"mode":"delta"}')$c$);
select cron.schedule('campaigns', '0 18 * * *', $c$select private.invoke_edge('sync-catalog', '{"what":"campaigns"}')$c$);
select cron.schedule('vouchers', '15 */6 * * *', $c$select private.invoke_edge('sync-catalog', '{"what":"vouchers"}')$c$);
select cron.schedule('push-drain', '* * * * *', $c$select private.invoke_edge('send-push', '{}')$c$);

select cron.schedule('risk', '5 * * * *', $c$select public.refresh_risk_scores()$c$);
select cron.schedule('vip', '30 17 * * *', $c$select public.refresh_vip_tiers()$c$);
select cron.schedule('promote', '0 17 * * *', $c$select public.promote_withdrawable()$c$);
select cron.schedule('drift', '45 17 * * *', $c$
  do $d$
  declare n int;
  begin
    select count(*) into n from public.check_wallet_drift();
    if n > 0 then
      perform private.notify_admins('Lệch ví so với sổ cái', n || ' dòng lệch cần kiểm tra', jsonb_build_object('rows', n));
    end if;
  end $d$$c$);

select cron.schedule('purge-ext-login', '*/30 * * * *',
  $c$delete from public.extension_login_codes where expires_at < now() - interval '1 hour'$c$);
select cron.schedule('retention', '0 20 * * 0', $c$
  delete from public.price_snapshots where day < current_date - 400;
  delete from public.sync_errors where created_at < now() - interval '90 days'$c$);
