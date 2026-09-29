import { render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

vi.mock("@/app/admin/orders/actions", () => ({ assignOrder: vi.fn(), searchUsers: vi.fn(), atLookup: vi.fn() }));
vi.mock("next/navigation", () => ({ useRouter: () => ({ push: vi.fn() }) }));

import type { LedgerLine } from "./order-detail-data";
import { OrderDetailSheet } from "./order-detail-sheet";
import { OrdersTable, type OrderRow } from "./orders-table";

const base = { id: "o1", transaction_id: "TX1", merchant_id: "shopee", order_time: "2026-09-01T03:00:00Z", value_vnd: 500000,
  commission_vnd: 25000, user_cashback_vnd: 12500, at_status: 1, credit_state: "credited", product_name: "Áo" } as OrderRow;

describe("OrdersTable", () => {
  it("renders matched and unmatched rows with actions", () => {
    const users = new Map([["u1", { id: "u1", email: "lan@x.vn", short_id: 7 }]]);
    render(<OrdersTable rows={[{ ...base, user_id: "u1" }, { ...base, id: "o2", transaction_id: "TX2", user_id: null }]}
      users={users} merchants={new Map([["shopee", "Shopee"]])} searchParams={{ merchant: "shopee" }} />);
    expect(screen.getByText("lan@x.vn")).toBeInTheDocument();
    expect(screen.getByText("Chưa khớp")).toBeInTheDocument();
    expect(screen.getAllByRole("button", { name: "Gán user" })).toHaveLength(2);
    expect(screen.getAllByRole("link", { name: "Chi tiết" })[0]).toHaveAttribute("href", "?merchant=shopee&order=o1");
  });
  it("shows empty state", () => {
    render(<OrdersTable rows={[]} users={new Map()} merchants={new Map()} searchParams={{}} />);
    expect(screen.getByText("Không có đơn hàng")).toBeInTheDocument();
  });
});

describe("OrderDetailSheet", () => {
  it("shows ledger and raw AT payload", () => {
    const ledger: LedgerLine[] = [{ id: 1, entry_type: "cashback_credit", amount_vnd: 12500, created_at: "2026-09-01T03:00:00Z", available_at: null, note: null }];
    render(<OrderDetailSheet order={base} closeHref="?" detail={{ raw: { a: 1 }, click: null, ledger }} />);
    expect(screen.getByText("Đơn TX1")).toBeInTheDocument();
    expect(screen.getByText(/cashback_credit/)).toBeInTheDocument();
    expect(screen.getByText(/"a": 1/)).toBeInTheDocument();
  });
});
