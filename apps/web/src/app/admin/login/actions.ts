"use server";

import { redirect } from "next/navigation";
import { z } from "zod";
import { fail, ok, type ActionResult } from "@/lib/admin/action-result";
import { webBaseUrl } from "@/lib/auth-redirect";
import { createServerSupabase } from "@/lib/supabase/server";

const emailSchema = z.string().trim().toLowerCase().pipe(z.email().max(254));
const sendSchema = z.object({ email: emailSchema, captchaToken: z.string().min(1).max(4096) });
const verifySchema = z.object({ email: emailSchema, token: z.string().trim().regex(/^\d{6,10}$/) });

function authFailure(err: { status?: number }, fallback: string): ActionResult<never> {
  if (err.status === 429) return fail({ message: "rate_limited" });
  return { ok: false, error: fallback };
}

export async function sendEmailOtp(input: { email: string; captchaToken: string }): Promise<ActionResult> {
  const parsed = sendSchema.safeParse(input);
  if (!parsed.success) return fail({ message: "invalid_input" });
  try {
    const supabase = await createServerSupabase();
    const { error } = await supabase.auth.signInWithOtp({
      email: parsed.data.email,
      // Admins are provisioned in `admins`; never create accounts from the admin login.
      options: { shouldCreateUser: false, captchaToken: parsed.data.captchaToken },
    });
    if (error) return authFailure(error, "Không thể gửi mã. Kiểm tra email hoặc thử lại sau.");
    return ok("Đã gửi mã xác thực tới email của bạn.");
  } catch {
    return fail(null);
  }
}

export async function verifyEmailOtp(input: { email: string; token: string }): Promise<ActionResult> {
  const parsed = verifySchema.safeParse(input);
  if (!parsed.success) return fail({ message: "invalid_input" });
  try {
    const supabase = await createServerSupabase();
    const { error } = await supabase.auth.verifyOtp({ ...parsed.data, type: "email" });
    if (error) return authFailure(error, "Mã không đúng hoặc đã hết hạn.");
    return ok();
  } catch {
    return fail(null);
  }
}

export async function signInWithGoogle() {
  let target: string | null = null;
  try {
    const supabase = await createServerSupabase();
    const { data, error } = await supabase.auth.signInWithOAuth({
      provider: "google",
      options: { redirectTo: `${webBaseUrl()}/auth/callback?next=/admin/mfa` },
    });
    if (!error) target = data.url;
  } catch {
    target = null;
  }
  redirect(target ?? "/admin/login?e=oauth");
}
