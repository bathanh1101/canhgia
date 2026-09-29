/** Admin routes that render without the guarded shell (auth flow). */
const AUTH_PATHS = new Set(["/admin/login", "/admin/mfa"]);

export function isAdminAuthPath(pathname: string | null): boolean {
  return pathname !== null && AUTH_PATHS.has(pathname);
}
