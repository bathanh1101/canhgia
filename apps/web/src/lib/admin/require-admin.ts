import { NextResponse } from "next/server";
import { redirect } from "next/navigation";
import { createServerSupabase } from "@/lib/supabase/server";

/** Layer 2: aal2 + `is_admin()` RPC (admins row AND aal2, revocation = delete the row). Call in every admin page/action/route. */
export async function requireAdmin() {
  const supabase = await createServerSupabase();
  const { data } = await supabase.auth.getClaims();
  const claims = data?.claims;
  if (!claims) redirect("/admin/login");
  if (claims.aal !== "aal2") redirect("/admin/mfa");
  const { data: ok, error } = await supabase.rpc("is_admin");
  if (error || !ok) redirect("/admin/login?e=forbidden");
  return { supabase, adminId: claims.sub, email: typeof claims.email === "string" ? claims.email : "" };
}

/** Route-handler variant: JSON 401 (no/expired session) or 403 (not aal2 / not an admin) instead of an HTML redirect. */
export async function requireAdminApi() {
  const supabase = await createServerSupabase();
  const { data } = await supabase.auth.getClaims();
  const claims = data?.claims;
  const deny = (status: 401 | 403) =>
    ({ ok: false as const, response: NextResponse.json({ error: status === 401 ? "unauthorized" : "forbidden" }, { status, headers: { "Cache-Control": "no-store" } }) });
  if (!claims) return deny(401);
  if (claims.aal !== "aal2") return deny(403);
  const { data: isAdmin, error } = await supabase.rpc("is_admin");
  if (error || !isAdmin) return deny(403);
  return { ok: true as const, supabase, adminId: claims.sub };
}
