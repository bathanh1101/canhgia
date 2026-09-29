import Link from "next/link";
import { Badge, type BadgeTone } from "@/components/ui/badge";
import { Card, CardContent } from "@/components/ui/card";
import { formatDateTime } from "@/lib/format";
import { evaluateSync, UNMATCHED_ALERT_RATIO, type SyncStateRow } from "./overview-logic";

export interface SyncErrorRow { id: number; job: string; error: string | null; created_at: string }
const TONE: Record<"ok" | "warn" | "bad", BadgeTone> = { ok: "success", warn: "warning", bad: "danger" };

export function SyncHealth({
  states, errors24h, errors, unmatchedCount, unmatchedRatio, now,
}: {
  states: SyncStateRow[]; errors24h: number; errors: SyncErrorRow[];
  unmatchedCount: number; unmatchedRatio: number; now?: number;
}) {
  const jobs = evaluateSync(states, now);
  const ratioBad = unmatchedRatio > UNMATCHED_ALERT_RATIO;
  return (
    <Card>
      <CardContent className="space-y-3">
        <div className="flex flex-wrap items-center gap-2">
          {jobs.map((j) => (
            <Badge key={j.job} tone={TONE[j.level]}>{j.job}: {j.text}</Badge>
          ))}
          {errors24h > 0 && <Badge tone="danger">{errors24h} lỗi đồng bộ trong 24h</Badge>}
          <Link href="/admin/orders?unmatched=1">
            <Badge tone={ratioBad ? "danger" : "neutral"}>
              Chưa khớp: {unmatchedCount} ({(unmatchedRatio * 100).toFixed(1)}%)
            </Badge>
          </Link>
        </div>
        <p className="text-xs text-text-muted">
          {states.map((s) => `${s.job}: ${formatDateTime(s.last_success_at)}`).join(" · ")}
        </p>
        {errors.length > 0 && (
          <details className="text-sm">
            <summary className="cursor-pointer font-medium">{errors.length} lỗi gần nhất</summary>
            <ul className="mt-2 max-h-56 space-y-1 overflow-auto">
              {errors.map((e) => (
                <li key={e.id} className="rounded bg-danger-tint px-2 py-1 text-xs">
                  {formatDateTime(e.created_at)} · {e.job} · {e.error ?? "-"}
                </li>
              ))}
            </ul>
          </details>
        )}
      </CardContent>
    </Card>
  );
}
