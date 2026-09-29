const TURNSTILE = "https://challenges.cloudflare.com";

function origin(url: string | undefined): string | null {
  try {
    return url ? new URL(url).origin : null;
  } catch {
    return null;
  }
}

/** CSP that still lets Next inline bootstrap scripts, Supabase (REST/realtime/storage images) and Turnstile work. */
export function buildCsp(supabaseUrl: string | undefined, dev: boolean): string {
  const sb = origin(supabaseUrl);
  const ws = sb ? sb.replace(/^http/, "ws") : null;
  const list = (...xs: (string | null)[]) => xs.filter(Boolean).join(" ");
  return [
    "default-src 'self'",
    `script-src ${list("'self'", "'unsafe-inline'", dev ? "'unsafe-eval'" : null, TURNSTILE)}`,
    "style-src 'self' 'unsafe-inline'",
    `img-src ${list("'self'", "data:", "blob:", sb)}`,
    "font-src 'self' data:",
    `connect-src ${list("'self'", sb, ws, TURNSTILE)}`,
    `frame-src ${TURNSTILE}`,
    "object-src 'none'",
    "base-uri 'self'",
    "form-action 'self'",
    "frame-ancestors 'none'",
  ].join("; ");
}

export function securityHeaders(supabaseUrl: string | undefined, dev: boolean) {
  return [
    { key: "Content-Security-Policy", value: buildCsp(supabaseUrl, dev) },
    { key: "X-Frame-Options", value: "DENY" },
    { key: "X-Content-Type-Options", value: "nosniff" },
    { key: "Referrer-Policy", value: "same-origin" },
  ];
}
