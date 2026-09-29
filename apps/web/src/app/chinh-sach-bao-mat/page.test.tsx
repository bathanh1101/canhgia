import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { contactLine } from "./contact-line";
import PrivacyPolicyPage from "./page";

describe("PrivacyPolicyPage", () => {
  it("lists collected data, third parties and rights", () => {
    const { container } = render(<PrivacyPolicyPage />);
    expect(screen.getByRole("heading", { level: 1 }).textContent).toBe("Chính sách bảo mật");
    for (const s of ["AccessTrade", "Supabase", "Firebase", "Cloudflare", "CCCD", "số tài khoản"])
      expect(container.textContent).toContain(s);
  });

  it("accepts only a well-formed support email", () => {
    expect(contactLine("help@canhgia.vn")).toBe("help@canhgia.vn");
    expect(contactLine("javascript:alert(1)")).toBe("");
    expect(contactLine(undefined)).toBe("");
  });
});
