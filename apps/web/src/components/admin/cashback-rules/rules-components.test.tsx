import { render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

vi.mock("@/app/admin/cashback-rules/actions", () => ({
  upsertRule: vi.fn(), toggleRule: vi.fn(), updateTier: vi.fn(), simulate: vi.fn(), saveSetting: vi.fn(),
}));

import { buildRuleRows } from "./rules-logic";
import { RulesTable } from "./rules-table";
import { SettingsEditor } from "./settings-editor";
import { Simulator } from "./simulator";
import { VipTiersTable } from "./vip-tiers-table";

describe("cashback rules components", () => {
  it("RulesTable shows commission, share, app keeps, state", () => {
    const rows = buildRuleRows([{ id: "shopee", name: "Shopee" }],
      [{ merchant_id: "shopee", category_key: "", commission_rate_bps: 500 }],
      [{ merchant_id: null, category_key: null, user_share_bps: 5000 }, { merchant_id: "shopee", category_key: null, user_share_bps: 0 }]);
    render(<RulesTable rows={rows} maxShareBps={8000} />);
    expect(screen.getByText("Mặc định toàn hệ thống")).toBeInTheDocument();
    expect(screen.getByText("5%")).toBeInTheDocument();
    expect(screen.getAllByText("Tắt").length).toBeGreaterThan(0);
    expect(screen.getAllByRole("button", { name: "Sửa" })).toHaveLength(2);
  });
  it("VipTiersTable shows bonus as percent", () => {
    render(<VipTiersTable tiers={[{ code: "gold", name: "Vàng", min_gmv_12m_vnd: 5_000_000, bonus_bps: 1000 }]} />);
    expect(screen.getByLabelText(/Thưởng VIP % hoa hồng gold/)).toHaveValue("10");
  });
  it("Simulator and SettingsEditor render forms", () => {
    render(<><Simulator merchants={[{ id: "shopee", name: "Shopee" }]} tiers={[{ code: "gold", name: "Vàng" }]} />
      <SettingsEditor values={{ min_withdraw_vnd: 50000, withdraw_eta_text: "1-2 ngày", landing_stats: { rating: 4.8, users: "10k" } }} /></>);
    expect(screen.getByRole("button", { name: "Tính thử" })).toBeInTheDocument();
    expect(screen.getByLabelText("Rút tối thiểu (VND)")).toHaveValue("50000");
    expect(screen.getByLabelText("Thời gian nhận tiền")).toHaveValue("1-2 ngày");
    expect(screen.getByLabelText("Đánh giá (0-5)")).toHaveValue("4.8");
  });
});
