-- Review hardening: unique bank transfer refs, admin audit for reads, TOTP-enrol gate, idempotent wallet adjust.

-- W1: one bank transfer reference proves at most one withdrawal.
create unique index withdrawals_transfer_ref_uq on public.withdrawals (transfer_ref) where transfer_ref is not null;

-- W3: audit trail for admin reads that bypass admin_* RPCs (orders export, KYC image views).
create function public.admin_log_action(p_action text, p_target jsonb default '{}')
returns void
language plpgsql security definer set search_path = pg_catalog, public as $$
begin
  if p_action not in ('export_orders', 'view_kyc') then perform private.raise_code('invalid_input', '{"field":"p_action"}'); end if;
  perform private.admin_gate(p_action, null, coalesce(p_target, '{}'));
end $$;

-- W6: "has an admins row", regardless of aal (needed before the first TOTP enrolment).
create function public.is_admin_candidate() returns boolean
language sql stable security definer set search_path = pg_catalog, public as $$
  select exists (select 1 from public.admins a where a.user_id = auth.uid())
$$;

-- W7: caller-supplied request id makes a retried adjustment idempotent (same id -> same ledger row).
drop function public.admin_adjust_wallet(uuid, bigint, text, uuid);
create function public.admin_adjust_wallet(p_user_id uuid, p_amount bigint, p_reason text, p_order_id uuid default null, p_request_id uuid default null)
returns bigint
language plpgsql security definer set search_path = pg_catalog, public as $$
declare
  v_admin uuid := private.admin_gate('adjust_wallet', p_user_id::text,
    jsonb_build_object('amount', p_amount, 'reason', p_reason, 'order_id', p_order_id, 'request_id', p_request_id));
  v_key text := 'adm:' || coalesce(p_request_id, gen_random_uuid())::text;
  v_id bigint;
begin
  if p_amount is null or p_amount = 0 then perform private.raise_code('invalid_input', '{"field":"p_amount"}'); end if;
  if nullif(btrim(p_reason), '') is null then perform private.raise_code('invalid_input', '{"field":"p_reason"}'); end if;
  if not exists (select 1 from public.wallets where user_id = p_user_id) then
    perform private.raise_code('invalid_input', '{"field":"p_user_id"}');
  end if;
  -- Look up first: the ledger BEFORE INSERT trigger moves balances, so ON CONFLICT DO NOTHING would still credit.
  -- A concurrent duplicate hits the unique key and aborts (no double credit).
  select l.id into v_id from public.wallet_ledger l where l.idempotency_key = v_key;
  if v_id is not null then
    if not exists (select 1 from public.wallet_ledger l where l.id = v_id and l.user_id = p_user_id and l.amount_vnd = p_amount) then
      perform private.raise_code('invalid_input', '{"field":"p_request_id"}');
    end if;
    return v_id;
  end if;
  insert into public.wallet_ledger (user_id, entry_type, amount_vnd, order_id, idempotency_key, note, created_by)
  values (p_user_id, 'admin_adjustment', p_amount, p_order_id, v_key, p_reason, v_admin)
  returning id into v_id;
  return v_id;
end $$;

revoke execute on function public.admin_log_action(text, jsonb), public.is_admin_candidate(),
  public.admin_adjust_wallet(uuid, bigint, text, uuid, uuid) from public, anon, service_role;
grant execute on function public.admin_log_action(text, jsonb), public.is_admin_candidate(),
  public.admin_adjust_wallet(uuid, bigint, text, uuid, uuid) to authenticated;
