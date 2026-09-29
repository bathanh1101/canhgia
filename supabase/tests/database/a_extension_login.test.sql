begin;
create extension if not exists pgtap with schema extensions;
grant execute on all functions in schema extensions to public;
select plan(13);

insert into auth.users (id, email) values ('a0000000-0000-0000-0000-00000000000a', 'a@x.io');
select set_config('t.hash', encode(extensions.digest('sekret', 'sha256'), 'hex'), true);
select set_config('t.code', (select code::text from public.start_extension_login(current_setting('t.hash'), '203.0.113.77', 'Chrome/130')), true);
select ok(current_setting('t.code')::uuid is not null, 'start returns a code');
select ok((select expires_at <= now() + interval '2 minutes' + interval '1 second' from public.extension_login_codes), 'expires in 2 minutes');

select throws_ok($$select public.consume_extension_login(current_setting('t.code')::uuid, 'sekret')$$, 'P0001', 'code_pending', 'consume before approval -> code_pending');
select throws_ok($$select public.consume_extension_login(current_setting('t.code')::uuid, 'wrong')$$, 'P0001', 'code_invalid', 'wrong secret -> code_invalid');
select throws_ok($$select public.consume_extension_login(gen_random_uuid(), 'sekret')$$, 'P0001', 'code_invalid', 'unknown code');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-0000-0000-00000000000a","role":"authenticated"}', true);
select results_eq($$select user_agent, ip_masked from public.get_extension_login_request(current_setting('t.code')::uuid)$$,
  $$values ('Chrome/130', '203.0.113.x')$$, 'approval screen shows masked ip');
select throws_ok($$select * from public.get_extension_login_request(gen_random_uuid())$$, 'P0001', 'code_invalid', 'unknown request');
select lives_ok($$select public.approve_extension_login(current_setting('t.code')::uuid)$$, 'approve');
select throws_ok($$select public.approve_extension_login(current_setting('t.code')::uuid)$$, 'P0001', 'code_invalid', 'cannot approve twice');
reset role;

select is(public.consume_extension_login(current_setting('t.code')::uuid, 'sekret'), 'a0000000-0000-0000-0000-00000000000a'::uuid, 'consume returns the approver');
select ok((select withdrawal_hold_until > now() + interval '23 hours' from public.profiles where id = 'a0000000-0000-0000-0000-00000000000a'), 'extension login -> 24h withdrawal hold');
select throws_ok($$select public.consume_extension_login(current_setting('t.code')::uuid, 'sekret')$$, 'P0001', 'code_invalid', 'single use');

-- IP throttle: 5 starts per 10 minutes (one already made above)
select code from public.start_extension_login(current_setting('t.hash'), '203.0.113.77', 'ua');
select code from public.start_extension_login(current_setting('t.hash'), '203.0.113.77', 'ua');
select code from public.start_extension_login(current_setting('t.hash'), '203.0.113.77', 'ua');
select code from public.start_extension_login(current_setting('t.hash'), '203.0.113.77', 'ua');
select throws_ok($$select * from public.start_extension_login(current_setting('t.hash'), '203.0.113.77', 'ua')$$, 'P0001', 'rate_limited', '6th start from the IP is rate limited');

select * from finish();
rollback;
