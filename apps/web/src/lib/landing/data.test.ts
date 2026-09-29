import { describe, expect, it } from "vitest";
import { landingLinks } from "./data";
import { publicSettingsSchema } from "./schema";

describe("landing data", () => {
  it("keeps only valid http(s) store links", () => {
    const l = landingLinks({
      NEXT_PUBLIC_PLAY_URL: "https://play.google.com/x",
      NEXT_PUBLIC_APPSTORE_URL: "javascript:alert(1)",
      NEXT_PUBLIC_CWS_URL: "",
    } as unknown as NodeJS.ProcessEnv);
    expect(l).toEqual({ play: "https://play.google.com/x", appstore: undefined, cws: undefined });
  });

  it("parses settings and drops malformed landing_stats", () => {
    const ok = publicSettingsSchema.parse({
      landing_stats: { rating: 4.8, users: "10K+" }, max_rate_bps: 1500, active_merchants: 6, min_withdraw_vnd: "50000",
    });
    expect(ok.landing_stats).toEqual({ rating: 4.8, users: "10K+" });
    expect(ok.min_withdraw_vnd).toBe(50000);
    const bad = publicSettingsSchema.parse({ landing_stats: { rating: "x" }, max_rate_bps: 0, active_merchants: 0 });
    expect(bad.landing_stats).toBeNull();
  });
});
