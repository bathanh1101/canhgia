import { describe, expect, it } from "vitest";
import { safeAdminNext } from "./auth-redirect";

describe("safeAdminNext", () => {
  it("keeps admin paths", () => {
    expect(safeAdminNext("/admin/orders?page=2")).toBe("/admin/orders?page=2");
    expect(safeAdminNext("/admin")).toBe("/admin");
  });
  it("rejects open redirects and non-admin paths", () => {
    for (const bad of ["//evil.com", "https://evil.com", "/administrator", "/admin\\..", "/", "", null, undefined]) {
      expect(safeAdminNext(bad as string | null)).toBe("/admin/mfa");
    }
  });
});
