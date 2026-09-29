-- Explicit grants for 02b. Default function privileges were revoked in 000100; table defaults of the platform are undone here.
revoke all on public.user_activity_days, public.missions, public.mission_claims, public.daily_checkins, public.coin_ledger,
  public.saved_vouchers, public.watchlist_items, public.missing_order_reports, public.product_key_rules, public.banks
  from anon, authenticated;
revoke all on sequence public.missing_order_code_seq from anon, authenticated;

grant select on public.user_activity_days, public.missions, public.mission_claims, public.daily_checkins, public.coin_ledger,
  public.saved_vouchers, public.watchlist_items, public.missing_order_reports, public.product_key_rules, public.banks
  to authenticated;
grant select on public.missions, public.banks to anon;
grant insert, delete on public.saved_vouchers to authenticated;
grant insert, delete on public.watchlist_items to authenticated;
grant update (target_price_vnd) on public.watchlist_items to authenticated;


grant execute on function
  public.touch_activity(), public.complete_onboarding(), public.update_profile(text, jsonb), public.bind_referral(text),
  public.daily_checkin(), public.get_mission_progress(), public.claim_mission(text), public.record_link_share(bigint),
  public.mark_notifications_read(bigint[]),
  public.submit_missing_order(text, text, date, bigint, text[]),
  public.admin_assign_order(uuid, uuid), public.admin_resolve_complaint(bigint, text, bigint, text),
  public.admin_upsert_cashback_rule(text, text, int, boolean, text), public.admin_update_vip_tier(text, int, bigint),
  public.admin_set_setting(text, jsonb), public.admin_set_user_lock(uuid, boolean, text),
  public.admin_update_flag(bigint, public.flag_status), public.admin_overview(date, date),
  public.admin_monthly_series(int), public.admin_merchant_mix(date, date), public.admin_user_stats(int),
  public.admin_top_users(int)
  to authenticated;

grant execute on function
  public.search_offers(text, text[], text, int, int), public.get_compare(bigint), public.get_price_history(bigint, int),
  public.estimate_cashback(text, text, bigint, text), public.get_merchant_rates(), public.get_public_settings()
  to anon, authenticated;

grant execute on function
  public.assign_product_groups(), public.evaluate_price_alerts(), public.refresh_vip_tiers(), public.refresh_risk_scores()
  to service_role;

-- the platform default-grants EXECUTE to service_role on new functions: keep it only on the service allowlist
do $$
declare
  f regprocedure;
begin
  for f in select p.oid::regprocedure from pg_proc p
            where p.pronamespace = 'public'::regnamespace
              and p.proname <> all (array['at_rate_limit_take', 'check_wallet_drift', 'claim_push_batch', 'consume_extension_login',
                'create_click', 'ingest_at_transactions', 'mark_push_sent', 'promote_withdrawable', 'set_click_link',
                'start_extension_login', 'sync_finish', 'sync_lock', 'sync_save', 'upsert_campaign_commissions', 'upsert_offers',
                'upsert_vouchers', 'assign_product_groups', 'evaluate_price_alerts', 'refresh_vip_tiers', 'refresh_risk_scores'])
  loop
    execute format('revoke execute on function %s from service_role', f);
  end loop;
end $$;
