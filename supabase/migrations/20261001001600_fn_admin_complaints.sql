-- Missing-order complaint resolution. > 2.000.000d needs a DIFFERENT second admin repeating the same amount (enforced here).
create function public.admin_resolve_complaint(p_id bigint, p_decision text, p_amount bigint, p_note text) returns text
language plpgsql security definer set search_path = pg_catalog, public as $$
declare
  v_admin uuid := private.admin_gate('resolve_complaint', p_id::text,
    jsonb_build_object('decision', p_decision, 'amount', p_amount, 'note', p_note));
  c public.missing_order_reports;
  v_hold int;
  v_order uuid;
begin
  if p_decision not in ('approved', 'rejected') then
    perform private.raise_code('invalid_input', '{"field":"p_decision"}');
  end if;
  select * into c from public.missing_order_reports where id = p_id for update;
  if not found or c.status not in ('pending', 'reviewing') then perform private.raise_code('invalid_state'); end if;

  if p_decision = 'rejected' then
    if nullif(btrim(p_note), '') is null then perform private.raise_code('invalid_input', '{"field":"p_note"}'); end if;
    update public.missing_order_reports set status = 'rejected', admin_note = p_note, resolved_at = now() where id = c.id;
    perform private.notify(c.user_id, 'system', 'Khiếu nại đơn hàng bị từ chối', p_note,
      jsonb_build_object('report_id', c.id, 'public_code', c.public_code));
    return 'rejected';
  end if;

  if p_amount is null or p_amount <= 0 or p_amount > c.order_value_vnd then
    perform private.raise_code('invalid_input', '{"field":"p_amount"}');
  end if;
  if exists (select 1 from public.orders o where o.merchant_id = c.merchant_id and o.transaction_id_norm = c.order_code_norm) then
    perform private.raise_code('invalid_state', '{"reason":"order_exists"}');
  end if;

  if p_amount > 2000000 then
    if c.first_approved_by is null then
      update public.missing_order_reports set status = 'reviewing', first_approved_by = v_admin, first_approved_at = now(),
        first_approved_amount = p_amount where id = c.id;
      return 'requires_second_approver';
    end if;
    if c.first_approved_by = v_admin then perform private.raise_code('forbidden', '{"reason":"same_admin"}'); end if;
    if c.first_approved_amount <> p_amount then
      perform private.raise_code('invalid_input', '{"field":"p_amount","reason":"amount_mismatch"}');
    end if;
  end if;

  select hold_days into v_hold from public.merchants where id = c.merchant_id;
  insert into public.orders (source, merchant_id, transaction_id, product_name, value_vnd, commission_vnd, order_time,
    user_id, matched_by, user_cashback_vnd, credit_state, confirmed_time, withdrawable_at)
  values ('manual', c.merchant_id, c.order_code, 'Khiếu nại ' || c.public_code, c.order_value_vnd, 0,
          private.vn_ts(c.purchased_on), c.user_id, 'complaint', p_amount, 'credited', now(),
          now() + make_interval(days => v_hold))
  returning id into v_order;
  perform private.apply_order_ledger(v_order);
  update public.missing_order_reports set status = 'approved', resolution_amount_vnd = p_amount, resolved_order_id = v_order,
    admin_note = p_note, resolved_at = now() where id = c.id;
  perform private.notify(c.user_id, 'wallet', 'Khiếu nại đơn hàng được duyệt', 'Bạn nhận ' || p_amount || 'đ hoàn tiền',
    jsonb_build_object('report_id', c.id, 'order_id', v_order));
  return 'approved';
end $$;
