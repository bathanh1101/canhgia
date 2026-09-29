import { NextRequest } from "next/server";
import { beforeEach, describe, expect, it, vi } from "vitest";

const getClaims = vi.fn();
vi.mock("@supabase/ssr", () => ({
  createServerClient: () => ({ auth: { getClaims } }),
}));

import { config, proxy } from "./proxy";

const req = (path: string) => new NextRequest(new URL(path, "http://localhost:3000"));

beforeEach(() => {
  process.env.NEXT_PUBLIC_SUPABASE_URL = "http://sb.local";
  process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY = "pk";
  getClaims.mockReset();
});

describe("proxy admin gate", () => {
  it("redirects an anonymous /admin/* request to /admin/login", async () => {
    getClaims.mockResolvedValue({ data: null });
    for (const p of ["/admin", "/admin/overview", "/admin/mfa?x=1"]) {
      const res = await proxy(req(p));
      expect(res.status).toBe(307);
      expect(new URL(res.headers.get("location")!).pathname).toBe("/admin/login");
    }
  });

  it("lets /admin/login through without a session", async () => {
    getClaims.mockResolvedValue({ data: null });
    const res = await proxy(req("/admin/login"));
    expect(res.headers.get("location")).toBeNull();
  });

  it("lets an authenticated session through (aal/admin checked later by requireAdmin)", async () => {
    getClaims.mockResolvedValue({ data: { claims: { sub: "u1", aal: "aal1" } } });
    const res = await proxy(req("/admin/overview"));
    expect(res.headers.get("location")).toBeNull();
  });

  it("does not gate non-admin auth paths", async () => {
    getClaims.mockResolvedValue({ data: null });
    const res = await proxy(req("/auth/callback"));
    expect(res.headers.get("location")).toBeNull();
  });

  it("only matches admin and auth routes", () => {
    expect(config.matcher).toEqual(["/admin/:path*", "/auth/:path*"]);
  });
});

describe("proxy pathname header", () => {
  it("forwards x-pathname to the app and ignores a spoofed value", async () => {
    getClaims.mockResolvedValue({ data: { claims: { sub: "u1" } } });
    const r = new NextRequest(new URL("/admin/mfa", "http://localhost:3000"), {
      headers: { "x-pathname": "/admin/login" },
    });
    const res = await proxy(r);
    expect(res.headers.get("x-middleware-request-x-pathname")).toBe("/admin/mfa");
  });
});
