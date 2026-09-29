import type { LandingData } from "@/lib/landing/schema";
import { DownloadCta } from "./download-cta";
import { Features } from "./features";
import { Hero } from "./hero";
import { HowItWorks } from "./how-it-works";
import { LandingFooter } from "./landing-footer";
import { LandingNav } from "./landing-nav";
import { PartnerStrip } from "./partner-strip";

export function LandingPage({ data }: { data: LandingData }) {
  const { settings, merchants, links } = data;
  const hasDownload = Boolean(links.play || links.appstore || links.cws);
  return (
    <>
      <LandingNav showDownload={hasDownload} />
      <main>
        <Hero settings={settings} links={links} />
        <PartnerStrip merchants={merchants} />
        <HowItWorks minWithdrawVnd={settings?.min_withdraw_vnd} />
        <Features settings={settings} />
        <DownloadCta links={links} />
      </main>
      <LandingFooter />
    </>
  );
}
