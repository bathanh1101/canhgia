import { NextResponse, type NextRequest } from "next/server";
import { safeAdminNext, webBaseUrl } from "@/lib/auth-redirect";
import { createServerSupabase } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

/** OAuth (Google) PKCE callback → session cookies → MFA step. */
export async function GET(request: NextRequest) {
  const base = webBaseUrl();
  const code = request.nextUrl.searchParams.get("code");
  const next = safeAdminNext(request.nextUrl.searchParams.get("next"));
  if (!code) return NextResponse.redirect(`${base}/admin/login?e=oauth`);
  try {
    const supabase = await createServerSupabase();
    const { error } = await supabase.auth.exchangeCodeForSession(code);
    if (error) return NextResponse.redirect(`${base}/admin/login?e=oauth`);
  } catch {
    return NextResponse.redirect(`${base}/admin/login?e=oauth`);
  }
  return NextResponse.redirect(`${base}${next}`);
}
