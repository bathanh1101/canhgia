import { LandingPage } from "@/components/landing/landing-page";
import { loadLandingData } from "@/lib/landing/data";

export const revalidate = 3600;

export default async function Home() {
  return <LandingPage data={await loadLandingData()} />;
}
