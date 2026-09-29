begin;
create extension if not exists pgtap with schema extensions;
grant execute on all functions in schema extensions to public;
select plan(36);

insert into auth.users (id, email) values
  ('a0000000-0000-0000-0000-0000000000f1', 'a@x.io'), ('a0000000-0000-0000-0000-0000000000f2', 'b@x.io'),
  ('a0000000-0000-0000-0000-0000000000f3', 'admin@x.io');
insert into public.admins (user_id) values ('a0000000-0000-0000-0000-0000000000f3');
insert into public.vouchers (id, merchant_id, external_id) overriding system value values (990001, 'shopee', 'rls-v');
insert into public.product_groups (id, group_key) overriding system value values (990001, 'rls-g');
insert into public.user_activity_days (user_id, day) values ('a0000000-0000-0000-0000-0000000000f2', current_date);
insert into public.daily_checkins (user_id, day, coins, streak) values ('a0000000-0000-0000-0000-0000000000f2', current_date, 50, 1);
insert into public.coin_ledger (user_id, amount, reason, idempotency_key) values ('a0000000-0000-0000-0000-0000000000f2', 50, 'x', 'rls-c');
insert into public.mission_claims (user_id, code, week_start, reward_amount) values ('a0000000-0000-0000-0000-0000000000f2', 'share_1', current_date, 1);
insert into public.saved_vouchers (user_id, voucher_id) values ('a0000000-0000-0000-0000-0000000000f2', 990001);
insert into public.watchlist_items (user_id, product_group_id, target_price_vnd) values ('a0000000-0000-0000-0000-0000000000f2', 990001, 5);
insert into public.missing_order_reports (user_id, merchant_id, order_code, purchased_on, order_value_vnd)
  values ('a0000000-0000-0000-0000-0000000000f2', 'shopee', 'RLS0001', current_date - 2, 100000);

select is((select count(*)::int from pg_tables where schemaname = 'public' and not rowsecurity), 0, 'RLS enabled on every public table');

-- ---- as A: sees none of B's rows
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-0000-0000-0000000000f1","role":"authenticated","aal":"aal1"}', true);
select is((select count(*)::int from public.user_activity_days), 0, 'A: no foreign activity');
select is((select count(*)::int from public.daily_checkins), 0, 'A: no foreign check-ins');
select is((select count(*)::int from public.coin_ledger), 0, 'A: no foreign coins');
select is((select count(*)::int from public.mission_claims), 0, 'A: no foreign claims');
select is((select count(*)::int from public.saved_vouchers), 0, 'A: no foreign saved vouchers');
select is((select count(*)::int from public.watchlist_items), 0, 'A: no foreign watchlist');
select is((select count(*)::int from public.missing_order_reports), 0, 'A: no foreign complaints');
select is((select count(*)::int from public.product_key_rules), 0, 'A: grouping rules are admin-only');
select cmp_ok((select count(*)::int from public.missions), '>=', 3, 'missions public');
select cmp_ok((select count(*)::int from public.banks), '>=', 20, 'banks public');

-- own-row CRUD on saved_vouchers / watchlist_items only
select lives_ok($$insert into public.saved_vouchers (user_id, voucher_id) values (auth.uid(), 990001)$$, 'A saves a voucher');
select throws_ok($$insert into public.saved_vouchers (user_id, voucher_id) values ('a0000000-0000-0000-0000-0000000000f2', 990001)$$, '42501', null, 'A cannot save for B');
select lives_ok($$insert into public.watchlist_items (user_id, product_group_id, target_price_vnd) values (auth.uid(), 990001, 100)$$, 'A watches a group');
select lives_ok($$update public.watchlist_items set target_price_vnd = 200$$, 'A edits own target price');
select is((select target_price_vnd from public.watchlist_items), 200::bigint, 'edit visible');
select throws_ok($$update public.watchlist_items set user_id = 'a0000000-0000-0000-0000-0000000000f2'$$, '42501', null, 'A cannot reassign a watch item');
select throws_ok($$update public.watchlist_items set last_notified_at = now()$$, '42501', null, 'A cannot touch server columns');
select throws_ok($$insert into public.watchlist_items (user_id, product_group_id, target_price_vnd) values (auth.uid(), 990001, 300)$$, '23505', null, 'duplicate (user, group) rejected');
select lives_ok($$delete from public.saved_vouchers$$, 'A deletes own saved voucher');
select is((select count(*)::int from public.saved_vouchers), 0, 'only own row was deletable');
select throws_ok($$insert into public.coin_ledger (user_id, amount, reason, idempotency_key) values (auth.uid(), 999999, 'x', 'hack')$$, '42501', null, 'no direct coin credit');
select throws_ok($$insert into public.missing_order_reports (user_id, merchant_id, order_code, purchased_on, order_value_vnd) values (auth.uid(), 'shopee', 'HACK001', current_date - 2, 1)$$, '42501', null, 'complaints only via submit fn');
select throws_ok($$insert into public.mission_claims (user_id, code, week_start, reward_amount) values (auth.uid(), 'share_1', current_date, 1)$$, '42501', null, 'no direct mission claim');
select throws_ok($$update public.missions set reward_amount = 1$$, '42501', null, 'missions read-only');
reset role;
select is((select coin_balance from public.profiles where id = 'a0000000-0000-0000-0000-0000000000f1'), 0::bigint, 'coin balance untouched');

-- ---- anon: reference data only
set local role anon;
select cmp_ok((select count(*)::int from public.missions), '>=', 3, 'anon reads missions');
select cmp_ok((select count(*)::int from public.banks), '>=', 20, 'anon reads banks');
select throws_ok($$select * from public.missing_order_reports$$, '42501', null, 'anon cannot read complaints');
select throws_ok($$select * from public.product_key_rules$$, '42501', null, 'anon cannot read grouping rules');
reset role;

-- ---- admin at aal2 sees B's complaint, at aal1 does not
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-0000-0000-0000000000f3","role":"authenticated","aal":"aal1"}', true);
select is((select count(*)::int from public.missing_order_reports), 0, 'admin without aal2: nothing');
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-0000-0000-0000000000f3","role":"authenticated","aal":"aal2"}', true);
select cmp_ok((select count(*)::int from public.missing_order_reports), '>=', 1, 'admin at aal2 reads complaints');
reset role;

-- ---- EXECUTE allowlists after 02b (supersede the 02a lists, which predate the read models)
select is((select array_agg(p.proname::text order by p.proname) from pg_proc p
            where p.pronamespace = 'public'::regnamespace and has_function_privilege('anon', p.oid, 'execute')),
  array['estimate_cashback', 'get_compare', 'get_merchant_rates', 'get_price_history', 'get_public_settings', 'search_offers'],
  'anon executes only the read models');
select is((select array_agg(p.proname::text order by p.proname) from pg_proc p
            where p.pronamespace = 'public'::regnamespace and has_function_privilege('service_role', p.oid, 'execute')),
  array['assign_product_groups', 'at_rate_limit_take', 'check_wallet_drift', 'claim_push_batch', 'consume_extension_login', 'create_click',
        'evaluate_price_alerts', 'ingest_at_transactions', 'mark_push_sent', 'promote_withdrawable', 'refresh_risk_scores',
        'refresh_vip_tiers', 'set_click_link', 'start_extension_login', 'sync_finish', 'sync_lock', 'sync_save',
        'upsert_campaign_commissions', 'upsert_offers', 'upsert_vouchers'],
  'service_role executes only the service fns');
select is((select array_agg(p.proname::text order by p.proname) from pg_proc p
            where p.pronamespace = 'public'::regnamespace and has_function_privilege('authenticated', p.oid, 'execute')),
  array['add_bank_account', 'admin_adjust_wallet', 'admin_assign_order', 'admin_claim_withdrawal', 'admin_log_action', 'admin_mark_paid', 'admin_merchant_mix',
        'admin_monthly_series', 'admin_overview', 'admin_reject_withdrawals', 'admin_resolve_complaint', 'admin_review_kyc',
        'admin_set_setting', 'admin_set_user_lock', 'admin_top_users', 'admin_update_flag', 'admin_update_vip_tier',
        'admin_upsert_cashback_rule', 'admin_user_stats', 'admin_verify_bank_account', 'approve_extension_login', 'bind_referral',
        'claim_mission', 'complete_onboarding', 'daily_checkin', 'estimate_cashback', 'get_compare', 'get_extension_login_request',
        'get_merchant_rates', 'get_mission_progress', 'get_price_history', 'get_public_settings', 'is_admin', 'is_admin_candidate', 'mark_notifications_read',
        'record_link_share', 'register_device', 'request_withdrawal', 'search_offers', 'set_withdraw_pin', 'submit_kyc',
        'submit_missing_order', 'touch_activity', 'update_profile', 'verify_pin'],
  'authenticated executes only the listed user/admin/read fns');
select is_empty($$select p.proname from pg_proc p where p.pronamespace = 'private'::regnamespace
                    and (has_function_privilege('authenticated', p.oid, 'execute') or has_function_privilege('anon', p.oid, 'execute'))$$,
  'private fns stay closed to API roles');

select * from finish();
rollback;
