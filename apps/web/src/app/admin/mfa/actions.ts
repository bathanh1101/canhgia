"use server";

import { z } from "zod";
import { fail, ok, type ActionResult } from "@/lib/admin/action-result";
import { createServerSupabase } from "@/lib/supabase/server";

const verifySchema = z.object({ factorId: z.uuid(), code: z.string().regex(/^\d{6}$/) });

export interface EnrolData { factorId: string; qr: string; secret: string }

/** First login only: enrol a TOTP factor. Refused without an `admins` row and when a verified factor already exists (no second-factor takeover at aal1). */
export async function startEnrol(): Promise<ActionResult<EnrolData>> {
  try {
    const supabase = await createServerSupabase();
    const { data: candidate, error: candErr } = await supabase.rpc("is_admin_candidate");
    if (candErr) return fail(null);
    if (!candidate) return fail({ message: "forbidden" });
    const { data: factors, error: listErr } = await supabase.auth.mfa.listFactors();
    if (listErr) return fail(null);
    if (factors.totp.length > 0) return fail({ message: "forbidden" });
    // Clean up abandoned enrolments so retries do not pile up.
    for (const f of factors.all.filter((x) => x.factor_type === "totp" && x.status === "unverified")) {
      await supabase.auth.mfa.unenroll({ factorId: f.id });
    }
    const { data, error } = await supabase.auth.mfa.enroll({
      factorType: "totp",
      friendlyName: `CanhGia ${new Date().toISOString()}`,
    });
    if (error || !data) return fail(null);
    return ok(undefined, { factorId: data.id, qr: data.totp.qr_code, secret: data.totp.secret });
  } catch {
    return fail(null);
  }
}

/** Verify a TOTP code (enrol confirmation or later logins) → session becomes aal2. */
export async function verifyTotp(input: { factorId: string; code: string }): Promise<ActionResult> {
  const parsed = verifySchema.safeParse(input);
  if (!parsed.success) return fail({ message: "invalid_input" });
  try {
    const supabase = await createServerSupabase();
    const { data: factors, error: listErr } = await supabase.auth.mfa.listFactors();
    if (listErr) return fail(null);
    const factor = factors.all.find((f) => f.id === parsed.data.factorId && f.factor_type === "totp");
    if (!factor) return fail({ message: "forbidden" });
    if (factor.status === "unverified" && factors.totp.length > 0) return fail({ message: "forbidden" });
    const { error } = await supabase.auth.mfa.challengeAndVerify(parsed.data);
    if (error) return { ok: false, error: "Mã xác thực không đúng. Vui lòng thử lại." };
    return ok();
  } catch {
    return fail(null);
  }
}
