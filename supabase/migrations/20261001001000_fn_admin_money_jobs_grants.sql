-- Admin money fns (each: is_admin() gate + audit row), then explicit EXECUTE grants (Sec-1).
create function private.admin_gate(p_action text, p_target text, p_detail jsonb default '{}') returns uuid
language plpgsql security definer set search_path = pg_catalog, public as $$
begin
  if not public.is_admin() then perform private.raise_code('forbidden'); end if;
  insert into public.admin_audit_log (admin_id, action, target, detail) values (auth.uid(), p_action, p_target, p_detail);
  return auth.uid();
end $$;

create function public.admin_claim_withdrawal(p_id uuid)
returns table (id uuid, status public.withdrawal_status, claimed_by uuid, claimed_at timestamptz)
language plpgsql security definer set search_path = pg_catalog, public as $$
declare
  v_admin uuid := private.admin_gate('claim_withdrawal', p_id::text);
  w public.withdrawals;
begin
  select * into w from public.withdrawals x
   where x.id = p_id and (x.status = 'pending' or (x.status = 'processing' and x.claimed_at < now() - interval '30 minutes'))
   for update skip locked;
  if not found then perform private.raise_code('invalid_state'); end if;
  update public.withdrawals x set status = 'processing', claimed_by = v_admin, claimed_at = now() where x.id = p_id;
  return query select x.id, x.status, x.claimed_by, x.claimed_at from public.withdrawals x where x.id = p_id;
end $$;

create function public.admin_mark_paid(p_ids uuid[], p_transfer_ref text)
returns table (id uuid, ok boolean, error text)
language plpgsql security definer set search_path = pg_catalog, public as $$
declare
  v_admin uuid := private.admin_gate('mark_paid', array_to_string(p_ids, ','), jsonb_build_object('transfer_ref', p_transfer_ref));
  v_id uuid;
  w public.withdrawals;
begin
  if nullif(btrim(p_transfer_ref), '') is null then perform private.raise_code('invalid_input', '{"field":"p_transfer_ref"}'); end if;
  foreach v_id in array coalesce(p_ids, '{}') loop
    id := v_id; ok := false; error := null;
    select * into w from public.withdrawals x where x.id = v_id for update;
    if not found or w.status <> 'processing' then error := 'invalid_state';
    elsif w.claimed_by is distinct from v_admin then error := 'not_claimer';
    elsif not exists (select 1 from public.bank_accounts b where b.id = w.bank_account_id and b.holder_name_verified) then
      error := 'bank_unverified';
    else
      update public.withdrawals x set status = 'paid', paid_by = v_admin, paid_at = now(), transfer_ref = p_transfer_ref
       where x.id = v_id;
      perform private.notify(w.user_id, 'wallet', 'Rút tiền thành công', 'Đã chuyển ' || w.amount || 'đ',
        jsonb_build_object('withdrawal_id', v_id));
      ok := true;
    end if;
    return next;
  end loop;
end $$;

create function public.admin_reject_withdrawals(p_ids uuid[], p_reason text)
returns table (id uuid, ok boolean, error text)
language plpgsql security definer set search_path = pg_catalog, public as $$
declare
  v_admin uuid := private.admin_gate('reject_withdrawals', array_to_string(p_ids, ','), jsonb_build_object('reason', p_reason));
  v_id uuid;
  w public.withdrawals;
begin
  if nullif(btrim(p_reason), '') is null then perform private.raise_code('invalid_input', '{"field":"p_reason"}'); end if;
  foreach v_id in array coalesce(p_ids, '{}') loop
    id := v_id; ok := false; error := null;
    select * into w from public.withdrawals x where x.id = v_id for update;
    if not found or w.status not in ('pending', 'processing') then error := 'invalid_state';
    elsif w.status = 'processing' and w.claimed_by is distinct from v_admin then error := 'not_claimer';
    else
      update public.withdrawals x set status = 'rejected', reject_reason = p_reason where x.id = v_id;
      insert into public.wallet_ledger (user_id, entry_type, amount_vnd, withdrawal_id, idempotency_key, note, created_by)
      values (w.user_id, 'withdrawal_refund', w.amount, v_id, 'wdr:' || v_id, p_reason, v_admin);
      perform private.notify(w.user_id, 'wallet', 'Yêu cầu rút tiền bị từ chối', p_reason,
        jsonb_build_object('withdrawal_id', v_id));
      ok := true;
    end if;
    return next;
  end loop;
end $$;

create function public.admin_verify_bank_account(p_id uuid) returns void
language plpgsql security definer set search_path = pg_catalog, public as $$
begin
  perform private.admin_gate('verify_bank_account', p_id::text);
  update public.bank_accounts set holder_name_verified = true where id = p_id and not holder_name_verified;
  if not found then perform private.raise_code('invalid_state'); end if;
end $$;

create function public.admin_review_kyc(p_user_id uuid, p_decision text, p_reason text) returns void
language plpgsql security definer set search_path = pg_catalog, public as $$
declare
  v_admin uuid := private.admin_gate('review_kyc', p_user_id::text, jsonb_build_object('decision', p_decision));
begin
  if p_decision not in ('verified', 'rejected') or (p_decision = 'rejected' and nullif(btrim(p_reason), '') is null) then
    perform private.raise_code('invalid_input', '{"field":"p_decision"}');
  end if;
  update public.kyc_profiles set status = p_decision::public.kyc_status, reject_reason = case when p_decision = 'rejected' then p_reason end,
    reviewed_by = v_admin, reviewed_at = now() where user_id = p_user_id and status = 'pending';
  if not found then perform private.raise_code('invalid_state'); end if;
  perform private.notify(p_user_id, 'system', case p_decision when 'verified' then 'Xác minh danh tính thành công'
    else 'Xác minh danh tính bị từ chối' end, p_reason, '{}');
end $$;

create function public.admin_adjust_wallet(p_user_id uuid, p_amount bigint, p_reason text, p_order_id uuid default null)
returns bigint
language plpgsql security definer set search_path = pg_catalog, public as $$
declare
  v_admin uuid := private.admin_gate('adjust_wallet', p_user_id::text,
    jsonb_build_object('amount', p_amount, 'reason', p_reason, 'order_id', p_order_id));
  v_id bigint;
begin
  if p_amount is null or p_amount = 0 then perform private.raise_code('invalid_input', '{"field":"p_amount"}'); end if;
  if nullif(btrim(p_reason), '') is null then perform private.raise_code('invalid_input', '{"field":"p_reason"}'); end if;
  if not exists (select 1 from public.wallets where user_id = p_user_id) then
    perform private.raise_code('invalid_input', '{"field":"p_user_id"}');
  end if;
  insert into public.wallet_ledger (user_id, entry_type, amount_vnd, order_id, idempotency_key, note, created_by)
  values (p_user_id, 'admin_adjustment', p_amount, p_order_id, 'adm:' || gen_random_uuid(), p_reason, v_admin)
  returning id into v_id;
  return v_id;
end $$;

-- Grants. Default privileges were revoked in 000100; everything is explicit here.
revoke execute on all functions in schema public from public, anon, authenticated, service_role;

grant execute on function
  public.is_admin(), public.verify_pin(text), public.set_withdraw_pin(text, uuid),
  public.request_withdrawal(uuid, bigint, uuid, uuid), public.submit_kyc(text, text, text, text),
  public.add_bank_account(text, text, text), public.register_device(text, text, text),
  public.get_extension_login_request(uuid), public.approve_extension_login(uuid),
  public.admin_claim_withdrawal(uuid), public.admin_mark_paid(uuid[], text),
  public.admin_reject_withdrawals(uuid[], text), public.admin_verify_bank_account(uuid),
  public.admin_review_kyc(uuid, text, text), public.admin_adjust_wallet(uuid, bigint, text, uuid)
  to authenticated;

grant execute on function
  public.ingest_at_transactions(text, jsonb), public.upsert_offers(text, jsonb), public.upsert_vouchers(jsonb),
  public.upsert_campaign_commissions(jsonb),
  public.create_click(uuid, text, text, text, bigint, public.click_source, text),
  public.set_click_link(bigint, text, text), public.at_rate_limit_take(int, text),
  public.sync_lock(text, int), public.sync_save(text, jsonb), public.sync_finish(text, boolean, text, timestamptz),
  public.start_extension_login(text, inet, text), public.consume_extension_login(uuid, text),
  public.claim_push_batch(int), public.mark_push_sent(bigint[]), public.promote_withdrawable(),
  public.check_wallet_drift()
  to service_role;
