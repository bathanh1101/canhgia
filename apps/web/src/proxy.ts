import { NextResponse, type NextRequest } from "next/server";
import { updateSession } from "@/lib/supabase/proxy-session";

const PUBLIC_ADMIN = new Set(["/admin/login"]);

/** Layer 1 of admin protection: session refresh + "needs a session". aal2/is_admin are enforced by requireAdmin() and the DB. */
export async function proxy(request: NextRequest) {
  const { pathname } = request.nextUrl;
  // Lets app/admin/layout.tsx skip the guarded shell on /admin/login and /admin/mfa. Always overwritten here.
  request.headers.set("x-pathname", pathname);
  const { response, claims } = await updateSession(request);
  const isAdminArea = pathname === "/admin" || pathname.startsWith("/admin/");
  if (isAdminArea && !PUBLIC_ADMIN.has(pathname) && !claims) {
    const url = request.nextUrl.clone();
    url.pathname = "/admin/login";
    url.search = "";
    return NextResponse.redirect(url);
  }
  return response();
}

export const config = {
  matcher: ["/admin/:path*", "/auth/:path*"],
};
