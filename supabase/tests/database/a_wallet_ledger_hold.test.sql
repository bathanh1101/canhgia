begin;
create extension if not exists pgtap with schema extensions;
select plan(25);

insert into public.merchants (id, name) values ('shopee', 'Shopee');
insert into auth.users (id, email) values
  ('a0000000-0000-0000-0000-00000000000a', 'a@x.io'), ('b0000000-0000-0000-0000-00000000000b', 'b@x.io');
select is((select count(*)::int from public.wallets where user_id in ('a0000000-0000-0000-0000-00000000000a', 'b0000000-0000-0000-0000-00000000000b')),
  2, 'signup trigger creates profile wallets');

insert into public.orders (id, source, merchant_id, transaction_id, user_id, credit_state) values
  ('c0000000-0000-0000-0000-000000000001', 'manual', 'shopee', 'T1', 'a0000000-0000-0000-0000-00000000000a', 'credited'),
  ('c0000000-0000-0000-0000-000000000002', 'manual', 'shopee', 'T2', 'a0000000-0000-0000-0000-00000000000a', 'credited'),
  ('c0000000-0000-0000-0000-000000000003', 'manual', 'shopee', 'T3', 'a0000000-0000-0000-0000-00000000000a', 'credited');

-- held credit: not withdrawable
insert into public.wallet_ledger (user_id, entry_type, amount_vnd, order_id, idempotency_key, available_at) values
  ('a0000000-0000-0000-0000-00000000000a', 'cashback_credit', 1000, 'c0000000-0000-0000-0000-000000000001', 'k1', now() + interval '30 days');
select results_eq($$select held_vnd, available_vnd from public.wallets where user_id = 'a0000000-0000-0000-0000-00000000000a'$$,
  $$values (1000::bigint, 0::bigint)$$, 'future available_at -> held');

-- partial reversal while held: held decreases, available untouched
insert into public.wallet_ledger (user_id, entry_type, amount_vnd, order_id, idempotency_key) values
  ('a0000000-0000-0000-0000-00000000000a', 'cashback_reversal', -400, 'c0000000-0000-0000-0000-000000000001', 'k2');
select results_eq($$select held_vnd, available_vnd from public.wallets where user_id = 'a0000000-0000-0000-0000-00000000000a'$$,
  $$values (600::bigint, 0::bigint)$$, 'reversal while held consumes held only');
insert into public.wallet_ledger (user_id, entry_type, amount_vnd, order_id, idempotency_key) values
  ('a0000000-0000-0000-0000-00000000000a', 'cashback_reversal', -600, 'c0000000-0000-0000-0000-000000000001', 'k3');
select results_eq($$select held_vnd, available_vnd from public.wallets where user_id = 'a0000000-0000-0000-0000-00000000000a'$$,
  $$values (0::bigint, 0::bigint)$$, 'full reversal while held -> zero');

-- credit with past/null available_at goes straight to available
insert into public.wallet_ledger (user_id, entry_type, amount_vnd, order_id, idempotency_key) values
  ('a0000000-0000-0000-0000-00000000000a', 'manual_credit', 500, 'c0000000-0000-0000-0000-000000000002', 'k4');
select results_eq($$select held_vnd, available_vnd, total_earned_vnd from public.wallets where user_id = 'a0000000-0000-0000-0000-00000000000a'$$,
  $$values (0::bigint, 500::bigint, 500::bigint)$$, 'null available_at -> available; total_earned nets reversals');

-- insufficient balance: rejected, wallet unchanged
select throws_ok($$insert into public.wallet_ledger (user_id, entry_type, amount_vnd, idempotency_key)
  values ('a0000000-0000-0000-0000-00000000000a', 'withdrawal_debit', -600, 'k5')$$, 'P0001', 'insufficient_balance', 'debit above available rejected');
select is((select available_vnd from public.wallets where user_id = 'a0000000-0000-0000-0000-00000000000a'), 500::bigint, 'wallet unchanged after rejection');
select throws_ok($$insert into public.wallet_ledger (user_id, entry_type, amount_vnd, order_id, idempotency_key)
  values ('a0000000-0000-0000-0000-00000000000a', 'manual_reversal', -600, 'c0000000-0000-0000-0000-000000000002', 'k5b')$$,
  'P0001', 'insufficient_balance', 'reversal after promotion beyond available rejected');

-- duplicate idempotency key
select throws_ok($$insert into public.wallet_ledger (user_id, entry_type, amount_vnd, idempotency_key)
  values ('a0000000-0000-0000-0000-00000000000a', 'manual_credit', 5, 'k4')$$, '23505', null, 'idempotency_key unique');

-- admin_adjustment may go negative
insert into public.wallet_ledger (user_id, entry_type, amount_vnd, idempotency_key) values
  ('a0000000-0000-0000-0000-00000000000a', 'admin_adjustment', -700, 'k6');
select is((select available_vnd from public.wallets where user_id = 'a0000000-0000-0000-0000-00000000000a'), -200::bigint, 'admin_adjustment may go negative');
select throws_ok($$insert into public.wallet_ledger (user_id, entry_type, amount_vnd, idempotency_key)
  values ('a0000000-0000-0000-0000-00000000000a', 'withdrawal_debit', -1, 'k7')$$, 'P0001', 'insufficient_balance', 'other entries cannot deepen a negative');

-- promotion: due held -> available, marks promoted_at
insert into public.wallet_ledger (user_id, entry_type, amount_vnd, order_id, idempotency_key, available_at) values
  ('b0000000-0000-0000-0000-00000000000b', 'cashback_credit', 300, 'c0000000-0000-0000-0000-000000000003', 'k8', now() + interval '30 days');
select is(public.promote_withdrawable(), 0, 'nothing due yet');
-- now() is frozen inside a txn: make the row due by rewriting available_at with the guard off
alter table public.wallet_ledger disable trigger wallet_ledger_guard;
update public.wallet_ledger set available_at = now() - interval '1 day' where idempotency_key = 'k8';
alter table public.wallet_ledger enable trigger wallet_ledger_guard;
select is(public.promote_withdrawable(), 1, 'one held row promoted');
select results_eq($$select held_vnd, available_vnd from public.wallets where user_id = 'b0000000-0000-0000-0000-00000000000b'$$,
  $$values (0::bigint, 300::bigint)$$, 'promotion moves held -> available');
select is(public.promote_withdrawable(), 0, 'promotion is idempotent');
-- reversal after promotion consumes available
insert into public.wallet_ledger (user_id, entry_type, amount_vnd, order_id, idempotency_key) values
  ('b0000000-0000-0000-0000-00000000000b', 'cashback_reversal', -300, 'c0000000-0000-0000-0000-000000000003', 'k9');
select results_eq($$select held_vnd, available_vnd from public.wallets where user_id = 'b0000000-0000-0000-0000-00000000000b'$$,
  $$values (0::bigint, 0::bigint)$$, 'reversal after promotion consumes available');

-- immutability
select throws_ok($$update public.wallet_ledger set amount_vnd = 1 where idempotency_key = 'k1'$$, 'P0001', 'ledger_immutable', 'amount immutable');
select throws_ok($$delete from public.wallet_ledger where idempotency_key = 'k1'$$, 'P0001', 'ledger_immutable', 'no delete');
select throws_ok($$update public.wallet_ledger set promoted_at = now() where idempotency_key = 'k8'$$, 'P0001', 'ledger_immutable', 'promoted_at set only once');
select throws_ok($$update public.wallet_ledger set note = 'x' where idempotency_key = 'k1'$$, 'P0001', 'ledger_immutable', 'note immutable');
select lives_ok($$update public.wallet_ledger set promoted_at = now() where idempotency_key = 'k1'$$, 'promoted_at null->set allowed');

-- pending_vnd follows orders
insert into public.orders (id, source, merchant_id, transaction_id, user_id, credit_state, user_cashback_vnd) values
  ('c0000000-0000-0000-0000-000000000004', 'manual', 'shopee', 'T4', 'b0000000-0000-0000-0000-00000000000b', 'pending', 250);
select is((select pending_vnd from public.wallets where user_id = 'b0000000-0000-0000-0000-00000000000b'), 250::bigint, 'pending_vnd from pending order');
update public.orders set user_id = 'a0000000-0000-0000-0000-00000000000a' where id = 'c0000000-0000-0000-0000-000000000004';
select results_eq($$select user_id, pending_vnd from public.wallets order by user_id$$,
  $$values ('a0000000-0000-0000-0000-00000000000a'::uuid, 250::bigint), ('b0000000-0000-0000-0000-00000000000b'::uuid, 0::bigint)$$, 'reassignment moves pending');
update public.orders set credit_state = 'credited' where id = 'c0000000-0000-0000-0000-000000000004';
select is((select pending_vnd from public.wallets where user_id = 'a0000000-0000-0000-0000-00000000000a'), 0::bigint, 'pending cleared on credit');

select is_empty($$select * from public.check_wallet_drift()$$, 'no wallet drift');
select * from finish();
rollback;
