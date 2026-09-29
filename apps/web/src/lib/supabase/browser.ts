import { createBrowserClient } from "@supabase/ssr";
import type { Database } from "./database.types";

// NEXT_PUBLIC_* must be referenced literally for Next to inline them in the client bundle.
export function createBrowserSupabase() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
  if (!url || !key) throw new Error("Missing Supabase public env");
  return createBrowserClient<Database>(url, key);
}
