import { describe, expect, it } from "vitest";
import { buildCsp, securityHeaders } from "./security-headers";

describe("securityHeaders", () => {
  const h = Object.fromEntries(securityHeaders("https://abc.supabase.co", false).map((x) => [x.key, x.value]));

  it("blocks framing, sniffing and leaks referrers", () => {
    expect(h["X-Frame-Options"]).toBe("DENY");
    expect(h["X-Content-Type-Options"]).toBe("nosniff");
    expect(h["Referrer-Policy"]).toBe("same-origin");
    expect(h["Content-Security-Policy"]).toContain("frame-ancestors 'none'");
  });

  it("CSP allows Supabase (http + ws) and Turnstile only", () => {
    const csp = buildCsp("https://abc.supabase.co", false);
    expect(csp).toContain("connect-src 'self' https://abc.supabase.co wss://abc.supabase.co https://challenges.cloudflare.com");
    expect(csp).toContain("img-src 'self' data: blob: https://abc.supabase.co");
    expect(csp).toContain("frame-src https://challenges.cloudflare.com");
    expect(csp).not.toContain("unsafe-eval");
    expect(buildCsp("http://127.0.0.1:54321", true)).toContain("'unsafe-eval'");
  });

  it("tolerates a missing or malformed Supabase URL", () => {
    expect(buildCsp(undefined, false)).toContain("connect-src 'self' https://challenges.cloudflare.com");
    expect(buildCsp("not a url", false)).not.toContain("undefined");
  });
});
