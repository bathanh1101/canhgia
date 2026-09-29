"use server";

import { revalidatePath } from "next/cache";
import { type ActionResult, fail, ok } from "@/lib/admin/action-result";
import { requireAdmin } from "@/lib/admin/require-admin";
import { escapeLike, type UserRef } from "@/components/admin/orders/orders-query";
import {
  assignSchema, atLookupResultSchema, atLookupSchema, type AtLookupResult, userSearchSchema,
} from "@/components/admin/orders/orders-action-schemas";

const invalid = fail({ message: "invalid_input" });

export async function assignOrder(orderId: string, userId: string): Promise<ActionResult> {
  const { supabase } = await requireAdmin();
  const p = assignSchema.safeParse({ orderId, userId });
  if (!p.success) return invalid;
  const { error } = await supabase.rpc("admin_assign_order", { p_order_id: p.data.orderId, p_user_id: p.data.userId });
  if (error) return fail(error);
  revalidatePath("/admin/orders");
  return ok("Đã gán đơn hàng cho người dùng");
}

export async function searchUsers(q: string): Promise<ActionResult<UserRef[]>> {
  const { supabase } = await requireAdmin();
  const p = userSearchSchema.safeParse(q);
  if (!p.success) return invalid;
  const base = supabase.from("profiles").select("id,email,short_id").limit(10);
  const { data, error } = await (/^\d{1,9}$/.test(p.data)
    ? base.eq("short_id", Number(p.data))
    : base.ilike("email", `%${escapeLike(p.data)}%`));
  if (error) return fail(error);
  return ok(undefined, data ?? []);
}

export async function atLookup(input: unknown): Promise<ActionResult<AtLookupResult>> {
  const { supabase } = await requireAdmin();
  const p = atLookupSchema.safeParse(input);
  if (!p.success) return invalid;
  const { data, error } = await supabase.functions.invoke("admin-at-lookup", { body: p.data });
  if (error) {
    // Edge errors arrive as FunctionsHttpError with the JSON body in `context`.
    const body = await (error as { context?: Response }).context?.json().catch(() => null);
    return fail({ message: typeof body?.error === "string" ? body.error : "" });
  }
  const r = atLookupResultSchema.safeParse(data);
  return r.success ? ok(undefined, r.data) : fail({ message: "" });
}
