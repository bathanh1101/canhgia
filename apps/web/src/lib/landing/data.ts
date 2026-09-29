import { createClient } from "@supabase/supabase-js";
import { z } from "zod";
import { supabaseEnv } from "@/lib/supabase/env";
import type { Database } from "@/lib/supabase/database.types";
import {
  merchantRateSchema, publicSettingsSchema, type LandingData, type LandingLinks,
} from "./schema";

const httpUrl = z.url({ protocol: /^https?$/ });

function link(v: string | undefined) {
  const r = httpUrl.safeParse(v);
  return r.success ? r.data : undefined;
}

export function landingLinks(env: NodeJS.ProcessEnv = process.env): LandingLinks {
  return {
    play: link(env.NEXT_PUBLIC_PLAY_URL),
    appstore: link(env.NEXT_PUBLIC_APPSTORE_URL),
    cws: link(env.NEXT_PUBLIC_CWS_URL),
  };
}

/** Public anon reads (ISR). Failures degrade to "no stats / no merchants" rather than breaking the page. */
export async function loadLandingData(): Promise<LandingData> {
  const links = landingLinks();
  try {
    const { url, key } = supabaseEnv();
    const supabase = createClient<Database>(url, key, { auth: { persistSession: false } });
    const [settings, rates] = await Promise.all([
      supabase.rpc("get_public_settings"),
      supabase.rpc("get_merchant_rates"),
    ]);
    if (settings.error) console.error("landing: get_public_settings", settings.error.message);
    if (rates.error) console.error("landing: get_merchant_rates", rates.error.message);
    const parsedSettings = publicSettingsSchema.safeParse(settings.data);
    const parsedRates = z.array(merchantRateSchema).safeParse(rates.data ?? []);
    return {
      settings: parsedSettings.success ? parsedSettings.data : null,
      merchants: parsedRates.success ? parsedRates.data : [],
      links,
    };
  } catch (err) {
    console.error("landing: data load failed", err instanceof Error ? err.message : err);
    return { settings: null, merchants: [], links };
  }
}
