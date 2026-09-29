import type { KycView } from "@/components/admin/users/kyc-review-panel";
import type { ProfileData } from "@/components/admin/users/user-profile-sections";
import type { createServerSupabase } from "@/lib/supabase/server";

type Db = Awaited<ReturnType<typeof createServerSupabase>>;

async function sign(db: Db, path: string): Promise<string | null> {
  const { data, error } = await db.storage.from("kyc").createSignedUrl(path, 60);
  return error ? null : data.signedUrl;
}

/** Everything the profile page shows. Column lists are explicit: wallet_ledger has column-level grants, orders come from admin_orders. */
export async function loadUserProfile(db: Db, id: string): Promise<{ data: ProfileData; kyc: KycView | null } | null | { error: string }> {
  const [profile, risk, wallet, ledger, orders, clicks, devices, banks, referrals, flags, kyc] = await Promise.all([
    db.from("profiles").select("id,email,display_name,created_at,locked_at,vip_tier_code,referral_code").eq("id", id).maybeSingle(),
    db.from("user_risk").select("risk_score,level,lock_reason").eq("user_id", id).maybeSingle(),
    db.from("wallets").select("available_vnd,pending_vnd,held_vnd,total_earned_vnd").eq("user_id", id).maybeSingle(),
    db.from("wallet_ledger").select("id,entry_type,amount_vnd,note,created_at").eq("user_id", id).order("id", { ascending: false }).limit(50),
    db.from("admin_orders").select("id,transaction_id,merchant_id,value_vnd,user_cashback_vnd,credit_state,order_time").eq("user_id", id).order("order_time", { ascending: false }).limit(50),
    db.from("clicks").select("id,merchant_id,source,status,created_at").eq("user_id", id).order("id", { ascending: false }).limit(50),
    db.from("user_devices").select("id,platform,model,last_seen_at").eq("user_id", id).limit(10),
    db.from("bank_accounts").select("id,bank_bin,account_number,account_name,holder_name_verified").eq("user_id", id),
    db.from("referrals").select("id,referee_id,status,bonus_vnd,created_at").eq("referrer_id", id).order("id", { ascending: false }).limit(50),
    db.from("fraud_flags").select("id,type,status,score,created_at").eq("user_id", id).order("id", { ascending: false }).limit(50),
    db.from("kyc_profiles").select("status,full_name,id_number_last4,submitted_at,reject_reason,front_path,back_path").eq("user_id", id).maybeSingle(),
  ]);
  const failed = [profile, risk, wallet, ledger, orders, clicks, devices, banks, referrals, flags, kyc].find((r) => r.error);
  if (failed?.error) return { error: failed.error.message };
  if (!profile.data) return null;

  const k = kyc.data;
  const [frontUrl, backUrl] = k ? await Promise.all([sign(db, k.front_path), sign(db, k.back_path)]) : [null, null];
  const orderRows = (orders.data ?? []).map((o) => ({ ...o, id: o.id ?? "", merchant_id: o.merchant_id ?? "", value_vnd: o.value_vnd ?? 0, user_cashback_vnd: o.user_cashback_vnd ?? 0, credit_state: o.credit_state ?? "none" }));
  return {
    data: {
      profile: profile.data, risk: risk.data, wallet: wallet.data, ledger: ledger.data ?? [], orders: orderRows,
      clicks: clicks.data ?? [], devices: devices.data ?? [], banks: banks.data ?? [], referrals: referrals.data ?? [], flags: flags.data ?? [],
    },
    kyc: k ? { status: k.status, fullName: k.full_name, last4: k.id_number_last4, submittedAt: k.submitted_at, rejectReason: k.reject_reason, frontUrl, backUrl } : null,
  };
}
