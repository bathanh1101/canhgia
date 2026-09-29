import { render, screen } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { fakeSupabase } from "@/components/admin/withdrawals/test-fake-supabase";

const state = vi.hoisted(() => ({ db: null as unknown }));
vi.mock("@/lib/admin/require-admin", () => ({
  requireAdmin: async () => ({ supabase: state.db, adminId: "admin-1", email: "admin@test" }),
}));
vi.mock("next/cache", () => ({ revalidatePath: vi.fn() }));

import Page from "./page";

const now = new Date().toISOString();
const w = {
  id: "1a2b3c4d-1111-4222-8333-444455556666", user_id: "u1", amount: 150000, status: "pending", created_at: now,
  bank_bin: "970436", account_number: "1020304050", account_name: "NGUYEN VAN A", bank_account_id: "b1", risk_level: "low",
  claimed_by: null, claimed_at: null, paid_by: null, paid_at: null, transfer_ref: null, reject_reason: null,
};

describe("/admin/withdrawals", () => {
  beforeEach(() => {
    state.db = fakeSupabase({
      admin_withdrawals: [w, { ...w, id: "2a2b3c4d-1111-4222-8333-444455556666", risk_level: "high" }],
      profiles: [{ id: "u1", email: "minh@test.canhgia.local" }],
      kyc_profiles: [{ user_id: "u1", full_name: "NGUYEN VAN A" }],
      banks: [{ bin: "970436", code: "VCB" }],
      bank_accounts: [{ id: "b1", holder_name_verified: false }],
      app_settings: [{ key: "auto_payout_enabled", value: false }],
    });
  });

  it("renders the queue with masked account, unverified badge and disabled high-risk checkbox", async () => {
    render(await Page({ searchParams: Promise.resolve({}) }));
    expect(screen.getByRole("heading", { name: "Duyệt rút tiền" })).toBeInTheDocument();
    expect(screen.getAllByText("Chưa xác minh tên")).toHaveLength(2);
    expect(screen.getAllByText(/\*{6}4050/)).toHaveLength(2);
    expect(screen.getByText("Chưa kích hoạt (MVP)")).toBeInTheDocument();
    const boxes = screen.getAllByRole("checkbox", { name: /Chọn/ });
    expect(boxes.filter((b) => b.hasAttribute("disabled") || b.getAttribute("data-disabled") !== null)).toHaveLength(1);
  });

  it("renders the history tab", async () => {
    render(await Page({ searchParams: Promise.resolve({ tab: "history" }) }));
    expect(screen.getByText("Mã GD / lý do")).toBeInTheDocument();
  });
});
