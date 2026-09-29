import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@/lib/supabase/database.types";
import type { OrdersFilter } from "./orders-filter-schema";

const VN = "+07:00";

/** Escapes LIKE wildcards and drops characters that would break PostgREST `or()` syntax. */
export function escapeLike(s: string): string {
  return s.replace(/[,()"\\*]/g, "").replace(/[%_]/g, (c) => `\\${c}`);
}

/** 'YYYY-MM-DD' → the next day, same format (UTC date math, no DST issues). */
export function nextDay(d: string): string {
  return new Date(Date.parse(`${d}T00:00:00Z`) + 86_400_000).toISOString().slice(0, 10);
}

/**
 * Shared by the orders page and the export route. Reads the `admin_orders` view (full rows, is_admin()-gated).
 * `matchedUserIds` = users whose email matched `f.q` (resolved beforehand; view has no profiles embed).
 */
export function buildOrdersQuery(sb: SupabaseClient<Database>, f: OrdersFilter, matchedUserIds: string[] = []) {
  let q = sb.from("admin_orders").select("*", { count: "exact" })
    .order("order_time", { ascending: false }).order("id", { ascending: true });
  if (f.merchant) q = q.eq("merchant_id", f.merchant);
  if (f.state) q = q.eq("credit_state", f.state);
  if (f.unmatched) q = q.is("user_id", null);
  if (f.from) q = q.gte("order_time", `${f.from}T00:00:00${VN}`);
  if (f.to) q = q.lt("order_time", `${nextDay(f.to)}T00:00:00${VN}`);
  if (f.q) {
    const parts = [`transaction_id.ilike.%${escapeLike(f.q)}%`];
    if (matchedUserIds.length) parts.push(`user_id.in.(${matchedUserIds.join(",")})`);
    q = q.or(parts.join(","));
  }
  return q;
}

export interface UserRef { id: string; email: string | null; short_id: number }

/** Users whose email contains `q` (max 50) – ids only get interpolated after uuid validation. */
export async function findUserIdsByEmail(sb: SupabaseClient<Database>, q: string): Promise<string[]> {
  if (!q.includes("@") && q.length < 3) return [];
  const { data, error } = await sb.from("profiles").select("id").ilike("email", `%${escapeLike(q)}%`).limit(50);
  if (error) throw new Error(error.message);
  return (data ?? []).map((r) => r.id).filter((id) => /^[0-9a-f-]{36}$/i.test(id));
}

export async function loadUserRefs(sb: SupabaseClient<Database>, ids: (string | null)[]): Promise<Map<string, UserRef>> {
  const uniq = [...new Set(ids.filter((x): x is string => !!x))];
  if (!uniq.length) return new Map();
  const { data, error } = await sb.from("profiles").select("id,email,short_id").in("id", uniq);
  if (error) throw new Error(error.message);
  return new Map((data ?? []).map((u) => [u.id, u]));
}
