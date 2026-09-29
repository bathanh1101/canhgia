"use client";

import { toggleRule } from "@/app/admin/cashback-rules/actions";
import { Button } from "@/components/ui/button";
import type { RuleRow } from "./rules-logic";
import { useRunAction } from "./use-run-action";

export function RuleToggle({ row }: { row: RuleRow }) {
  const { pending, run } = useRunAction();
  const next = !row.enabled;
  const share = next ? row.inheritedBps : (row.ownShareBps ?? row.shareBps);
  return (
    <Button
      variant={row.enabled ? "outline" : "default"} size="sm" disabled={pending}
      aria-pressed={row.enabled}
      onClick={() => run(() => toggleRule(row.merchantId, row.categoryKey, next, share))}
    >
      {row.enabled ? "Tắt" : "Bật"}
    </Button>
  );
}
