#!/usr/bin/env bash
# Phase 02a concurrency checks against a LOCAL supabase db (run `supabase start` first):
#   1. two concurrent withdrawals of the full balance -> exactly one row, no negative balance
#   2. wrong PINs across separate transactions -> counter persists, 6th call raises pin_locked
# Leaves its rows behind (ledger is immutable): `supabase db reset` cleans up.
set -euo pipefail

DB_CONTAINER="${DB_CONTAINER:-supabase_db_canhgia}"
psql_() { docker exec -i "$DB_CONTAINER" psql -U postgres -X -q -v ON_ERROR_STOP=1 -t -A "$@"; }

UID_="$(cat /proc/sys/kernel/random/uuid)"
BANK="$(cat /proc/sys/kernel/random/uuid)"
TOK_A="$(cat /proc/sys/kernel/random/uuid)"
TOK_B="$(cat /proc/sys/kernel/random/uuid)"
KEY_A="$(cat /proc/sys/kernel/random/uuid)"
KEY_B="$(cat /proc/sys/kernel/random/uuid)"
AMOUNT=1000000
CLAIMS="{\"sub\":\"$UID_\",\"role\":\"authenticated\",\"aal\":\"aal1\"}"

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

psql_ <<SQL
insert into auth.users (id, email) values ('$UID_', 'race-$UID_@example.test');
insert into public.kyc_profiles (user_id, full_name, full_name_norm, id_number_last4, id_number_hmac, front_path, back_path, status)
  values ('$UID_', 'Race', 'race', '0000', 'h-$UID_', 'f', 'b', 'verified');
insert into public.bank_accounts (id, user_id, bank_bin, account_number, account_name, account_name_norm)
  values ('$BANK', '$UID_', '970436', '0123456789', 'Race', 'race');
insert into public.wallet_ledger (user_id, entry_type, amount_vnd, idempotency_key)
  values ('$UID_', 'manual_credit', $AMOUNT, 'race-seed-$UID_');
insert into private.user_pins (user_id, pin_hash) values ('$UID_', extensions.crypt('123456', extensions.gen_salt('bf')));
insert into private.pin_tokens (token, user_id) values ('$TOK_A', '$UID_'), ('$TOK_B', '$UID_');
SQL

session() { # key token hold_seconds
  psql_ <<SQL
begin;
set local role authenticated;
select set_config('request.jwt.claims', '$CLAIMS', true);
select withdrawal_id from public.request_withdrawal('$1', $AMOUNT, '$BANK', '$2');
select pg_sleep($3);
commit;
SQL
}

echo "== 1. concurrent full-balance withdrawals"
session "$KEY_A" "$TOK_A" 2 >$TMP/race_a.out 2>$TMP/race_a.err & PID_A=$!
sleep 0.7
session "$KEY_B" "$TOK_B" 0 >$TMP/race_b.out 2>$TMP/race_b.err & PID_B=$!
RC_A=0; RC_B=0
wait "$PID_A" || RC_A=$?
wait "$PID_B" || RC_B=$?

ROWS="$(psql_ -c "select count(*) from public.withdrawals where user_id = '$UID_'")"
AVAIL="$(psql_ -c "select available_vnd from public.wallets where user_id = '$UID_'")"
DRIFT="$(psql_ -c "select count(*) from public.check_wallet_drift() where user_id = '$UID_'")"
echo "session A rc=$RC_A, session B rc=$RC_B, withdrawals=$ROWS, available=$AVAIL, drift rows=$DRIFT"
[ "$ROWS" = "1" ] || fail "expected exactly 1 withdrawal, got $ROWS"
[ "$AVAIL" = "0" ] || fail "expected available 0, got $AVAIL"
[ "$DRIFT" = "0" ] || fail "wallet drift detected"
[ $((RC_A == 0)) -ne $((RC_B == 0)) ] || fail "expected exactly one session to succeed (A=$RC_A B=$RC_B)"
LOSER_ERR="$(cat $TMP/race_a.err $TMP/race_b.err)"
grep -q "insufficient_balance" <<<"$LOSER_ERR" || fail "loser did not fail with insufficient_balance: $LOSER_ERR"
echo "OK: no double withdrawal"

echo "== 2. PIN lockout persists across separate transactions"
verify() {
  psql_ <<SQL 2>&1 || true
begin;
set local role authenticated;
select set_config('request.jwt.claims', '$CLAIMS', true);
select ok, attempts_left from public.verify_pin('000000');
commit;
SQL
}
for i in 1 2 3 4 5; do
  OUT="$(verify)"
  echo "wrong PIN #$i -> $OUT"
done
LEFT="$(psql_ -c "select failed_attempts, locked_until is not null from private.user_pins where user_id = '$UID_'")"
[ "$LEFT" = "0|t" ] || fail "5th wrong PIN should have committed a lock, got $LEFT"
OUT="$(verify)"
grep -q "pin_locked" <<<"$OUT" || fail "6th call should raise pin_locked, got: $OUT"
echo "OK: pin_locked after 5 wrong attempts (counter committed across transactions)"
