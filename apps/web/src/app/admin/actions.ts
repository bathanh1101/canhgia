"use server";

import { redirect } from "next/navigation";
import { createServerSupabase } from "@/lib/supabase/server";

export async function signOut() {
  try {
    const supabase = await createServerSupabase();
    await supabase.auth.signOut();
  } catch {
    // Cookies are cleared best-effort; the login page re-validates the session anyway.
  }
  redirect("/admin/login");
}
