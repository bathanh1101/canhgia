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
