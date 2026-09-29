begin;
create extension if not exists pgtap with schema extensions;
grant execute on all functions in schema extensions to public; -- 000100 revokes default EXECUTE; pgtap must survive role switches

select plan(24);

-- authenticated must not execute any service fn (Sec-1): SQLSTATE 42501
set local role authenticated;
select throws_ok(c, '42501', null, 'authenticated denied: ' || c) from unnest(array[
  $$select * from public.ingest_at_transactions('j', '[]')$$,
  $$select * from public.upsert_offers('m', '[]')$$,
  $$select public.upsert_vouchers('[]')$$,
  $$select public.upsert_campaign_commissions('[]')$$,
  $$select * from public.create_click(gen_random_uuid(), 'm', null, null, null, 'app', null)$$,
  $$select public.set_click_link(1, null, null)$$,
  $$select public.at_rate_limit_take(1)$$,
  $$select public.sync_lock('j', 10)$$,
  $$select public.sync_save('j', null)$$,
  $$select public.sync_finish('j', true, null, now())$$,
  $$select * from public.start_extension_login(repeat('a', 64), '1.2.3.4', 'ua')$$,
  $$select public.consume_extension_login(gen_random_uuid(), 's')$$,
  $$select * from public.claim_push_batch(1)$$,
  $$select public.mark_push_sent('{1}')$$,
  $$select public.promote_withdrawable()$$,
  $$select * from public.check_wallet_drift()$$
]) c;
reset role;

set local role anon;
select throws_ok($$select * from public.verify_pin('123456')$$, '42501', null, 'anon cannot verify_pin');
reset role;

-- allowlists straight from pg_proc: catches any new fn that slipped a default grant
select is((select array_agg(p.proname::text order by p.proname) from pg_proc p
            where p.pronamespace = 'public'::regnamespace and has_function_privilege('authenticated', p.oid, 'execute')),
  array['add_bank_account','admin_adjust_wallet','admin_claim_withdrawal','admin_mark_paid','admin_reject_withdrawals',
        'admin_review_kyc','admin_verify_bank_account','approve_extension_login','get_extension_login_request','is_admin',
        'register_device','request_withdrawal','set_withdraw_pin','submit_kyc','verify_pin'],
  'authenticated executes only the listed user fns');
select is((select array_agg(p.proname::text order by p.proname) from pg_proc p
            where p.pronamespace = 'public'::regnamespace and has_function_privilege('service_role', p.oid, 'execute')),
  array['at_rate_limit_take','check_wallet_drift','claim_push_batch','consume_extension_login','create_click',
        'ingest_at_transactions','mark_push_sent','promote_withdrawable','set_click_link','start_extension_login',
        'sync_finish','sync_lock','sync_save','upsert_campaign_commissions','upsert_offers','upsert_vouchers'],
  'service_role executes only the service fns');
select is_empty($$select p.proname from pg_proc p where p.pronamespace = 'public'::regnamespace
                    and has_function_privilege('anon', p.oid, 'execute')$$, 'anon executes nothing in public');
select is_empty($$select p.proname from pg_proc p where p.pronamespace = 'private'::regnamespace
                    and (has_function_privilege('authenticated', p.oid, 'execute') or has_function_privilege('anon', p.oid, 'execute'))$$,
  'private fns not executable by api roles');
select ok(not has_schema_privilege('authenticated', 'private', 'usage'), 'private schema not usable by authenticated');

-- a function created after the migrations gets no implicit grant
create function public.zz_probe() returns int language sql as 'select 1';
select ok(not has_function_privilege('authenticated', 'public.zz_probe()', 'execute'), 'new fn has no authenticated grant');
select ok(not has_function_privilege('anon', 'public.zz_probe()', 'execute'), 'new fn has no anon grant');

select * from finish();
rollback;
