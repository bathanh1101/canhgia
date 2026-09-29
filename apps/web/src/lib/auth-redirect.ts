/** Accepts only same-site admin paths (blocks open redirects such as //evil.com or absolute URLs). */
export function safeAdminNext(next: string | null | undefined, fallback = "/admin/mfa"): string {
  if (!next || !next.startsWith("/admin") || next.startsWith("//") || next.includes("\\")) return fallback;
  if (next !== "/admin" && !next.startsWith("/admin/") && !next.startsWith("/admin?")) return fallback;
  return next;
}

export function webBaseUrl(): string {
  const url = process.env.WEB_BASE_URL;
  if (!url) throw new Error("Missing WEB_BASE_URL");
  return url.replace(/\/+$/, "");
}
