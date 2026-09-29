"use client";

import { toast } from "@/components/ui/sonner";
import type { ActionResult } from "@/lib/admin/action-result";

/** Toasts a server-action result (success message or the Vietnamese error). */
export function notifyResult(result: ActionResult<unknown>) {
  if (result.ok) toast.success(result.message ?? "Thành công");
  else toast.error(result.error);
}
