import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { KpiGrid } from "./kpi-grid";
import { MerchantMixChart } from "./merchant-mix-chart";
import { MonthlyChart } from "./monthly-chart";
import { SyncHealth } from "./sync-health";
import { TopUsersTable } from "./top-users-table";
import { UserStats } from "./user-stats";

const k = { gmv_vnd: 2_000_000, commission_vnd: 100_000, paid_to_users_vnd: 60_000, net_vnd: 40_000, pending_commission_vnd: 5_000 };

describe("overview components", () => {
  it("KpiGrid shows values and delta vs previous period", () => {
    render(<KpiGrid current={k} previous={{ ...k, gmv_vnd: 1_000_000 }} />);
    expect(screen.getByText("GMV")).toBeInTheDocument();
    expect(screen.getByText("2.000.000đ")).toBeInTheDocument();
    expect(screen.getByText(/100% so với kỳ trước/)).toBeInTheDocument();
  });
  it("SyncHealth shows red alert for stale tx_recent and unmatched ratio", () => {
    render(
      <SyncHealth
        now={Date.parse("2026-09-29T12:00:00Z")} errors24h={2} unmatchedCount={4} unmatchedRatio={0.2}
        states={[{ job: "tx_recent", last_success_at: "2026-09-29T08:00:00Z", last_error: null }]}
        errors={[{ id: 1, job: "tx_recent", error: "upstream", created_at: "2026-09-29T11:00:00Z" }]}
      />,
    );
    expect(screen.getByText(/Quá 2 giờ chưa đồng bộ/)).toBeInTheDocument();
    expect(screen.getByText(/2 lỗi đồng bộ trong 24h/)).toBeInTheDocument();
    expect(screen.getByText(/Chưa khớp: 4 \(20.0%\)/)).toBeInTheDocument();
    expect(screen.getByText(/1 lỗi gần nhất/)).toBeInTheDocument();
  });
  it("UserStats and TopUsersTable render", () => {
    render(<><UserStats stats={{ newUsersMonth: 12, d30Retention: 0.256, dau: [{ day: "d", count: 7 }] }} />
      <TopUsersTable rows={[{ user_id: "u", email: "lan@x.vn", gmv_vnd: 1000, cashback_vnd: 50, orders: 2 }]} /></>);
    expect(screen.getByText("25,6%")).toBeInTheDocument();
    expect(screen.getByText("lan@x.vn")).toBeInTheDocument();
  });
  it("charts mount without data crashes", () => {
    render(<><MonthlyChart data={[]} /><MerchantMixChart data={[]} /></>);
    expect(screen.getByText("Chưa có hoa hồng trong kỳ.")).toBeInTheDocument();
    expect(screen.getByRole("img", { name: /12 tháng/ })).toBeInTheDocument();
  });
});
