import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import type { LandingData } from "@/lib/landing/schema";
import { LandingPage } from "./landing-page";

const empty: LandingData = { settings: null, merchants: [], links: {} };
const FORBIDDEN = ["tức thì", "500K+", "12 tỷ", "20%", "50+", "4.8"];

describe("LandingPage", () => {
  it("renders the L1 sections with honest copy when settings are null", () => {
    const { container } = render(<LandingPage data={empty} />);
    for (const s of FORBIDDEN) expect(container.textContent).not.toContain(s);
    expect(screen.getByRole("heading", { level: 1 }).textContent).toContain("Hoàn tiền mỗi đơn");
    expect(screen.getByText("Nhận hoàn tiền chỉ với 3 bước")).toBeInTheDocument();
    expect(screen.getByText("Mọi công cụ để mua đúng giá, đúng lúc")).toBeInTheDocument();
    expect(screen.getByText("Rút tiền trong 1 ngày làm việc")).toBeInTheDocument();
    expect(screen.getByText("Hoàn tiền mỗi đơn", { selector: "h3" })).toBeInTheDocument();
    expect(container.querySelector("dl")).toBeNull(); // no stats block
    expect(container.querySelector("a[href^='http']")).toBeNull(); // no store buttons
  });

  it("renders live values, stats and store links when provided", () => {
    const data: LandingData = {
      settings: {
        landing_stats: { rating: 4.7, users: "10K+" },
        max_rate_bps: 1500,
        active_merchants: 6,
        min_withdraw_vnd: 50000,
      },
      merchants: [{ merchant_id: "shopee", name: "Shopee", badge_letter: "S", max_user_rate_bps: 800 }],
      links: { play: "https://play.google.com/store/apps/details?id=x" },
    };
    const { container } = render(<LandingPage data={data} />);
    expect(container.textContent).toContain("Hoàn tiền đến 15%");
    expect(container.textContent).toContain("6 sàn & đối tác");
    expect(container.textContent).toContain("10K+");
    expect(container.textContent).toContain("★ 4,7");
    expect(container.textContent).not.toContain("12 tỷ");
    expect(container.textContent).toContain("từ 50.000đ");
    expect(screen.getByText("Shopee")).toBeInTheDocument();
    expect(container.querySelector("a[href^='https://play.google.com']")).not.toBeNull();
    expect(screen.queryByText("App Store")).toBeNull();
    expect(screen.getAllByText("Minh họa").length).toBeGreaterThan(0);
  });
});
