-- User-callable KYC / bank / device / extension-approval fns (authenticated).

create function public.submit_kyc(p_full_name text, p_id_number text, p_front_path text, p_back_path text)
returns public.kyc_status
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare
  v_uid uuid := private.require_uid();
  v_pepper text;
  v_hmac text;
  v_path text;
begin
  if (select locked_at from public.profiles where id = v_uid) is not null then
    perform private.raise_code('account_locked');
  end if;
  if private.norm_vn(p_full_name) is null then perform private.raise_code('invalid_input', '{"field":"p_full_name"}'); end if;
  if p_id_number is null or p_id_number !~ '^(\d{9}|\d{12})$' then
    perform private.raise_code('invalid_input', '{"field":"p_id_number"}');
  end if;
  foreach v_path in array array[p_front_path, p_back_path] loop
    if v_path is null or v_path not like v_uid::text || '/%'
       or not exists (select 1 from storage.objects o where o.bucket_id = 'kyc' and o.name = v_path) then
      perform private.raise_code('invalid_input', jsonb_build_object('field', case when v_path = p_front_path then 'p_front_path' else 'p_back_path' end));
    end if;
  end loop;
  select decrypted_secret into v_pepper from vault.decrypted_secrets where name = 'cccd_pepper';
  if v_pepper is null then perform private.raise_code('invalid_input', '{"reason":"cccd_pepper_missing"}'); end if;
  v_hmac := encode(extensions.hmac(p_id_number, v_pepper, 'sha256'), 'hex');
  insert into public.kyc_profiles (user_id, full_name, full_name_norm, id_number_last4, id_number_hmac, front_path, back_path)
  values (v_uid, btrim(p_full_name), private.norm_vn(p_full_name), right(p_id_number, 4), v_hmac, p_front_path, p_back_path)
  on conflict (user_id) do update set full_name = excluded.full_name, full_name_norm = excluded.full_name_norm,
    id_number_last4 = excluded.id_number_last4, id_number_hmac = excluded.id_number_hmac, front_path = excluded.front_path,
    back_path = excluded.back_path, status = 'pending', reject_reason = null, submitted_at = now(), reviewed_by = null, reviewed_at = null;
  if exists (select 1 from public.kyc_profiles k where k.id_number_hmac = v_hmac and k.user_id <> v_uid) then
    perform private.flag(v_uid, 'shared_identity', 80, jsonb_build_object('user_id', v_uid), 'kyc:' || v_hmac || ':' || v_uid);
  end if;
  return 'pending';
end $$;

create function public.add_bank_account(p_bank_bin text, p_account_number text, p_account_name text) returns uuid
language plpgsql security definer set search_path = pg_catalog, public as $$
declare
  v_uid uuid := private.require_uid();
  k public.kyc_profiles;
  v_id uuid;
begin
  select * into k from public.kyc_profiles where user_id = v_uid and status = 'verified';
  if not found then perform private.raise_code('kyc_required'); end if;
  if p_bank_bin is null or p_bank_bin !~ '^\d{6}$' then perform private.raise_code('invalid_input', '{"field":"p_bank_bin"}'); end if;
  if p_account_number is null or p_account_number !~ '^\d{6,19}$' then
    perform private.raise_code('invalid_input', '{"field":"p_account_number"}');
  end if;
  if private.norm_vn(p_account_name) is distinct from k.full_name_norm then
    perform private.raise_code('invalid_input', '{"field":"p_account_name"}');
  end if;
  insert into public.bank_accounts (user_id, bank_bin, account_number, account_name, account_name_norm, is_default)
  values (v_uid, p_bank_bin, p_account_number, btrim(p_account_name), private.norm_vn(p_account_name),
          not exists (select 1 from public.bank_accounts b where b.user_id = v_uid))
  on conflict (user_id, bank_bin, account_number) do nothing returning id into v_id;
  if v_id is null then
    select id into v_id from public.bank_accounts where user_id = v_uid and bank_bin = p_bank_bin and account_number = p_account_number;
    return v_id;
  end if;
  if exists (select 1 from public.bank_accounts b where b.bank_bin = p_bank_bin and b.account_number = p_account_number and b.user_id <> v_uid) then
    perform private.flag(v_uid, 'shared_bank_account', 60, jsonb_build_object('bank_account_id', v_id), 'bank:' || v_id);
  end if;
  perform private.bump_hold(v_uid);
  return v_id;
end $$;

create function public.register_device(p_device_id text, p_platform text, p_model text) returns void
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare
  v_uid uuid := private.require_uid();
  v_hash text;
  v_had boolean;
  v_ins boolean;
begin
  if p_device_id is null or length(p_device_id) < 8 or p_platform is null then
    perform private.raise_code('invalid_input', '{"field":"p_device_id"}');
  end if;
  v_hash := encode(extensions.digest(p_device_id, 'sha256'), 'hex');
  perform pg_advisory_xact_lock(hashtext('dev:' || v_uid));
  v_had := exists (select 1 from public.user_devices d where d.user_id = v_uid);
  insert into public.user_devices (user_id, device_hash, platform, model) values (v_uid, v_hash, p_platform, p_model)
  on conflict (user_id, device_hash) do update set last_seen_at = now(), model = coalesce(excluded.model, public.user_devices.model)
  returning (xmax = 0) into v_ins;
  if v_ins then
    -- best-effort signal: keep only the 10 most recently seen devices per user
    delete from public.user_devices where id in (
      select d.id from public.user_devices d where d.user_id = v_uid order by d.last_seen_at desc, d.id desc offset 10);
    if v_had then perform private.bump_hold(v_uid); end if;
  end if;
end $$;

create function public.get_extension_login_request(p_code uuid)
returns table (user_agent text, ip_masked text, expires_at timestamptz)
language plpgsql security definer set search_path = pg_catalog, public as $$
declare
  c public.extension_login_codes;
begin
  perform private.require_uid();
  select * into c from public.extension_login_codes x where x.code = p_code and x.status = 'pending' and x.expires_at > now();
  if not found then perform private.raise_code('code_invalid'); end if;
  user_agent := c.user_agent; expires_at := c.expires_at;
  ip_masked := case when family(c.requester_ip) = 4 then regexp_replace(host(c.requester_ip), '\.\d+$', '.x')
                    else regexp_replace(host(c.requester_ip), '^((?:[0-9a-f]*:){3}).*$', '\1x') end;
  return next;
end $$;

create function public.approve_extension_login(p_code uuid) returns void
language plpgsql security definer set search_path = pg_catalog, public as $$
declare
  v_uid uuid := private.require_uid();
begin
  update public.extension_login_codes set status = 'approved', user_id = v_uid
   where code = p_code and status = 'pending' and expires_at > now();
  if not found then perform private.raise_code('code_invalid'); end if;
end $$;
