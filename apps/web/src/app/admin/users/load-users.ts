import type { FlagView } from "@/components/admin/users/fraud-alerts-list";
import type { RiskRow } from "@/components/admin/users/risk-table";
import type { createServerSupabase } from "@/lib/supabase/server";

type Db = Awaited<ReturnType<typeof createServerSupabase>>;
type SP = Record<string, string | string[] | undefined>;
const first = (v: string | string[] | undefined) => (Array.isArray(v) ? v[0] : v) ?? "";
/** PostgREST `ilike` wildcards and filter-syntax characters must not come from user input. */
export const safeSearch = (q: string) => q.replace(/[%_,()*\\]/g, "").trim().slice(0, 64);
const uniq = <T,>(xs: (T | null | undefined)[]) => [...new Set(xs.filter((x): x is T => x != null))];

export async function loadOpenFlags(db: Db): Promise<{ flags: FlagView[]; held: { id: number; referee_id: string; referrer_id: string; bonus_vnd: number; created_at: string }[]; error?: string }> {
  const [f, h] = await Promise.all([
    db.from("fraud_flags").select("id,type,score,user_id,evidence,created_at").eq("status", "open").order("created_at", { ascending: false }).limit(200),
    db.from("referrals").select("id,referee_id,referrer_id,bonus_vnd,created_at").eq("status", "held").order("created_at", { ascending: false }).limit(100),
  ]);
  if (f.error || h.error) return { flags: [], held: [], error: (f.error ?? h.error)?.message };
  const ids = uniq((f.data ?? []).map((x) => x.user_id));
  const p = ids.length ? await db.from("profiles").select("id,email,locked_at").in("id", ids) : { data: [], error: null };
  if (p.error) return { flags: [], held: [], error: p.error.message };
  const by = new Map((p.data ?? []).map((x) => [x.id, x]));
  const flags = (f.data ?? []).map((x): FlagView => ({
    id: x.id, type: x.type, score: x.score, userId: x.user_id, evidence: x.evidence, createdAt: x.created_at,
    email: by.get(x.user_id ?? "")?.email ?? "", locked: !!by.get(x.user_id ?? "")?.locked_at,
  }));
  return { flags, held: h.data ?? [] };
}

/** Risk list sorted by score. Email / KYC filters resolve to id lists first (each capped at 500). */
export async function loadRisk(db: Db, sp: SP, range: { from: number; to: number }): Promise<{ rows: RiskRow[]; total: number; error?: string }> {
  let idFilter: string[] | null = null;
  const narrow = (ids: string[]) => { idFilter = idFilter ? idFilter.filter((i) => ids.includes(i)) : ids; };
  const q = safeSearch(first(sp.q));
  if (q) {
    const r = await db.from("profiles").select("id").ilike("email", `%${q}%`).limit(500);
    if (r.error) return { rows: [], total: 0, error: r.error.message };
    narrow((r.data ?? []).map((x) => x.id));
  }
  const kyc = first(sp.kyc);
  if (["pending", "verified", "rejected"].includes(kyc)) {
    const r = await db.from("kyc_profiles").select("user_id").eq("status", kyc as "pending" | "verified" | "rejected").limit(500);
    if (r.error) return { rows: [], total: 0, error: r.error.message };
    narrow((r.data ?? []).map((x) => x.user_id));
  }
  if (idFilter !== null && (idFilter as string[]).length === 0) return { rows: [], total: 0 };

  let query = db.from("user_risk").select("user_id,risk_score,level,lock_reason,updated_at", { count: "exact" })
    .order("risk_score", { ascending: false }).order("updated_at", { ascending: false }).range(range.from, range.to);
  const level = first(sp.level);
  if (["low", "medium", "high"].includes(level)) query = query.eq("level", level);
  if (first(sp.locked) === "1") query = query.not("lock_reason", "is", null);
  if (idFilter !== null) query = query.in("user_id", idFilter);
  const { data, count, error } = await query;
  if (error) return { rows: [], total: 0, error: error.message };

  const ids = uniq((data ?? []).map((r) => r.user_id));
  const [p, k] = await Promise.all([
    db.from("profiles").select("id,email").in("id", ids),
    db.from("kyc_profiles").select("user_id,status").in("user_id", ids),
  ]);
  if (p.error || k.error) return { rows: [], total: 0, error: (p.error ?? k.error)?.message };
  const email = new Map((p.data ?? []).map((x) => [x.id, x.email ?? ""]));
  const kycBy = new Map((k.data ?? []).map((x) => [x.user_id, x.status]));
  return {
    total: count ?? 0,
    rows: (data ?? []).map((r) => ({
      userId: r.user_id, email: email.get(r.user_id) ?? "", score: r.risk_score, level: r.level, locked: r.lock_reason !== null,
      lockReason: r.lock_reason, kycStatus: kycBy.get(r.user_id) ?? null, updatedAt: r.updated_at,
    })),
  };
}
