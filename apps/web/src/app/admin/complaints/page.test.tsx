import { render, screen } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { fakeSupabase } from "@/components/admin/withdrawals/test-fake-supabase";

const state = vi.hoisted(() => ({ db: null as unknown, adminId: "admin-2" }));
vi.mock("@/lib/admin/require-admin", () => ({
  requireAdmin: async () => ({ supabase: state.db, adminId: state.adminId, email: "admin@test" }),
}));
vi.mock("next/cache", () => ({ revalidatePath: vi.fn() }));
vi.mock("next/navigation", () => ({ notFound: () => { throw new Error("not-found"); }, redirect: vi.fn() }));

import Page from "./page";
import DetailPage from "./[id]/page";

const report = {
  id: 7, public_code: "KN-000007", user_id: "u1", merchant_id: "shopee", order_code: "2509 abc123", order_code_norm: "2509ABC123",
  order_value_vnd: 3_000_000, purchased_on: "2026-09-20", status: "reviewing", admin_note: null, created_at: "2026-09-21T00:00:00Z",
  first_approved_by: "admin-1", first_approved_at: "2026-09-22T00:00:00Z", first_approved_amount: 2_500_000, resolution_amount_vnd: null,
  resolved_at: null, resolved_order_id: null, image_paths: ["u1/a.jpg"],
};
const tables = {
  missing_order_reports: [report],
  profiles: [{ id: "u1", email: "minh@test.canhgia.local" }],
  merchants: [{ id: "shopee", name: "Shopee" }],
  admin_orders: [],
  clicks: [],
};

describe("/admin/complaints", () => {
  beforeEach(() => { state.adminId = "admin-2"; state.db = fakeSupabase(tables, { signedUrl: "https://signed.test/c.jpg" }); });

  it("list renders the row with the second-approver badge", async () => {
    render(await Page({ searchParams: Promise.resolve({ status: "reviewing" }) }));
    expect(screen.getByRole("link", { name: "KN-000007" })).toHaveAttribute("href", "/admin/complaints/7");
    expect(screen.getByText("Chờ admin thứ 2")).toBeInTheDocument();
  });

  it("detail shows images, waiting badge with amount and the resolve action", async () => {
    render(await DetailPage({ params: Promise.resolve({ id: "7" }) }));
    expect(screen.getByAltText("Ảnh khiếu nại 1")).toHaveAttribute("src", "https://signed.test/c.jpg");
    expect(screen.getByText(/Chờ admin thứ 2 \(.*2\.500\.000đ\)/)).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Xử lý khiếu nại" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Tra cứu" })).toBeInTheDocument();
  });

  it("detail hides the resolve action once resolved and 404s on a bad id", async () => {
    state.db = fakeSupabase({ ...tables, missing_order_reports: [{ ...report, status: "approved" }] });
    render(await DetailPage({ params: Promise.resolve({ id: "7" }) }));
    expect(screen.queryByRole("button", { name: "Xử lý khiếu nại" })).toBeNull();
    await expect(DetailPage({ params: Promise.resolve({ id: "abc" }) })).rejects.toThrow("not-found");
  });
});
