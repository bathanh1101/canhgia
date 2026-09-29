"use client";

import { useTransition } from "react";
import { notifyResult } from "@/components/admin-kit/notify-result";
import type { ActionResult } from "@/lib/admin/action-result";

/** Runs a server action inside a transition, toasts the result, never lets a throw escape. */
export function useRunAction() {
  const [pending, start] = useTransition();
  const run = (fn: () => Promise<ActionResult<unknown>>, onOk?: () => void) =>
    start(async () => {
      try {
        const r = await fn();
        notifyResult(r);
        if (r.ok) onOk?.();
      } catch {
        notifyResult({ ok: false, error: "Đã có lỗi xảy ra. Vui lòng thử lại." });
      }
    });
  return { pending, run };
}
