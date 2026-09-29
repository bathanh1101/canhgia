import { render, screen } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { fakeSupabase } from "@/components/admin/withdrawals/test-fake-supabase";

const state = vi.hoisted(() => ({ db: null as unknown }));
vi.mock("@/lib/admin/require-admin", () => ({
  requireAdmin: async () => ({ supabase: state.db, adminId: "admin-1", email: "admin@test" }),
}));
vi.mock("next/cache", () => ({ revalidatePath: vi.fn() }));
vi.mock("next/navigation", () => ({ notFound: () => { throw new Error("not-found"); }, redirect: vi.fn() }));

import Page from "./page";
import ProfilePage from "./[id]/page";
import { safeSearch } from "./load-users";

const uid = "1a2b3c4d-1111-4222-8333-444455556666";
const tables = {
  fraud_flags: [
    { id: 1, type: "negative_balance_risk", score: 50, user_id: uid, status: "open", evidence: { order_id: "o1", delta: -5000 }, created_at: "2026-10-01T00:00:00Z" },
    { id: 2, type: "shared_bank_account", score: 50, user_id: uid, status: "open", evidence: { user_ids: [uid] }, created_at: "2026-10-01T00:00:00Z" },
  ],
  referrals: [],
  profiles: [{ id: uid, email: "lan@test.canhgia.local", locked_at: null, display_name: "Lan", created_at: "2026-09-01T00:00:00Z", vip_tier_code: null, referral_code: "LAN123" }],
  user_risk: [{ user_id: uid, risk_score: 75, level: "high", lock_reason: null, updated_at: "2026-10-01T00:00:00Z" }],
  kyc_profiles: [{ user_id: uid, status: "pending", full_name: "LAN", id_number_last4: "1234", submitted_at: "2026-09-02T00:00:00Z", reject_reason: null, front_path: "a/f.jpg", back_path: "a/b.jpg" }],
  wallets: [{ available_vnd: 1000, pending_vnd: 0, held_vnd: 0, total_earned_vnd: 1000 }],
};

describe("/admin/users", () => {
  beforeEach(() => { state.db = fakeSupabase(tables, { signedUrl: "https://signed.test/kyc.jpg" }); });

  it("alerts tab groups flags by type with type-specific actions", async () => {
    render(await Page({ searchParams: Promise.resolve({}) }));
    expect(screen.getByRole("heading", { name: /Nguy cơ âm ví/ })).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: /Trùng tài khoản ngân hàng/ })).toBeInTheDocument();
    expect(screen.getAllByText("lan@test.canhgia.local")).toHaveLength(2);
    expect(screen.getAllByRole("button", { name: "Điều chỉnh ví" })).toHaveLength(1);
  });

  it("risk tab renders the table", async () => {
    render(await Page({ searchParams: Promise.resolve({ tab: "risk", level: "high" }) }));
    expect(screen.getByText("Điểm rủi ro")).toBeInTheDocument();
    expect(screen.getByText("75")).toBeInTheDocument();
  });

  it("profile page shows KYC images from signed URLs and review buttons", async () => {
    render(await ProfilePage({ params: Promise.resolve({ id: uid }) }));
    expect(screen.getByAltText("CCCD mặt trước")).toHaveAttribute("src", "https://signed.test/kyc.jpg");
    expect(screen.getByRole("button", { name: "Duyệt" })).toBeInTheDocument();
    expect(screen.getByText("Sổ cái (50 gần nhất)")).toBeInTheDocument();
  });

  it("profile page 404s on a malformed id", async () => {
    await expect(ProfilePage({ params: Promise.resolve({ id: "nope" }) })).rejects.toThrow("not-found");
  });

  it("safeSearch strips PostgREST wildcards and separators", () => {
    expect(safeSearch("a%b_c,d(e)*")).toBe("abcde");
  });
});
