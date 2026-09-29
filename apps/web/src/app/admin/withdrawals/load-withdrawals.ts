import type { WithdrawalRow } from "@/components/admin/withdrawals/types";
import type { createServerSupabase } from "@/lib/supabase/server";

type Db = Awaited<ReturnType<typeof createServerSupabase>>;
const uniq = <T,>(xs: (T | null | undefined)[]) => [...new Set(xs.filter((x): x is T => x != null))];

/** Reads admin_withdrawals and joins profile/KYC/bank/risk/flag/admin data with batched `in()` queries. */
export async function loadWithdrawals(
  db: Db, statuses: ("pending" | "processing" | "paid" | "rejected")[], range?: { from: number; to: number },
): Promise<{ rows: WithdrawalRow[]; total: number; error?: string }> {
  let q = db.from("admin_withdrawals").select("*", { count: "exact" }).in("status", statuses)
    .order(statuses.includes("pending") ? "created_at" : "paid_at", { ascending: statuses.includes("pending"), nullsFirst: false });
  if (range) q = q.range(range.from, range.to);
  const { data, count, error } = await q;
  if (error) return { rows: [], total: 0, error: error.message };
  const ws = data ?? [];

  const userIds = uniq(ws.map((w) => w.user_id));
  const profileIds = uniq([...userIds, ...ws.map((w) => w.claimed_by), ...ws.map((w) => w.paid_by)]);
  const [profiles, kyc, risk, flags, banks, bankAccounts] = await Promise.all([
    db.from("profiles").select("id,email").in("id", profileIds),
    db.from("kyc_profiles").select("user_id,full_name").in("user_id", userIds),
    db.from("user_risk").select("user_id,risk_score,level").in("user_id", userIds),
    db.from("fraud_flags").select("user_id").eq("status", "open").in("user_id", userIds),
    db.from("banks").select("bin,code").in("bin", uniq(ws.map((w) => w.bank_bin))),
    db.from("bank_accounts").select("id,holder_name_verified").in("id", uniq(ws.map((w) => w.bank_account_id))),
  ]);
  const failed = [profiles, kyc, risk, flags, banks, bankAccounts].find((r) => r.error);
  if (failed?.error) return { rows: [], total: 0, error: failed.error.message };

  const email = new Map((profiles.data ?? []).map((p) => [p.id, p.email ?? ""]));
  const kycName = new Map((kyc.data ?? []).map((k) => [k.user_id, k.full_name]));
  const riskBy = new Map((risk.data ?? []).map((r) => [r.user_id, r]));
  const bankCode = new Map((banks.data ?? []).map((b) => [b.bin, b.code]));
  const verified = new Map((bankAccounts.data ?? []).map((b) => [b.id, b.holder_name_verified]));
  const flagCount = new Map<string, number>();
  for (const f of flags.data ?? []) if (f.user_id) flagCount.set(f.user_id, (flagCount.get(f.user_id) ?? 0) + 1);

  const rows = ws.map((w): WithdrawalRow => ({
    id: w.id ?? "",
    createdAt: w.created_at,
    userId: w.user_id ?? "",
    email: email.get(w.user_id ?? "") ?? "",
    kycName: kycName.get(w.user_id ?? "") ?? null,
    amount: w.amount ?? 0,
    status: w.status ?? "pending",
    bankName: bankCode.get(w.bank_bin ?? "") ?? w.bank_bin ?? "",
    bankBin: w.bank_bin ?? "",
    accountNumber: w.account_number ?? "",
    accountName: w.account_name ?? "",
    bankAccountId: w.bank_account_id ?? "",
    bankVerified: verified.get(w.bank_account_id ?? "") ?? false,
    snapshotRisk: w.risk_level ?? "low",
    liveRiskScore: riskBy.get(w.user_id ?? "")?.risk_score ?? null,
    liveRiskLevel: riskBy.get(w.user_id ?? "")?.level ?? null,
    flagCount: flagCount.get(w.user_id ?? "") ?? 0,
    claimedBy: w.claimed_by,
    claimedByEmail: w.claimed_by ? email.get(w.claimed_by) ?? null : null,
    claimedAt: w.claimed_at,
    paidByEmail: w.paid_by ? email.get(w.paid_by) ?? null : null,
    paidAt: w.paid_at,
    transferRef: w.transfer_ref,
    rejectReason: w.reject_reason,
  }));
  return { rows, total: count ?? rows.length };
}
