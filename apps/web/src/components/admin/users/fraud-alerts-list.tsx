import Link from "next/link";
import { EmptyState } from "@/components/admin-kit/states";
import { Badge } from "@/components/ui/badge";
import { Card } from "@/components/ui/card";
import { formatDateTime } from "@/lib/format";
import { FlagActions } from "./flag-actions";
import { UUID_RE, evidenceEntries, flagLabel, isUserKey } from "./flag-labels";

export interface FlagView {
  id: number; type: string; score: number; userId: string | null; email: string; locked: boolean; createdAt: string; evidence: unknown;
}

function Evidence({ evidence }: { evidence: unknown }) {
  return (
    <dl className="mt-2 grid gap-1 text-xs text-text-2">
      {evidenceEntries(evidence).map((e) => (
        <div key={e.key} className="flex flex-wrap gap-2">
          <dt className="text-text-muted">{e.key}:</dt>
          <dd className="flex flex-wrap gap-2">
            {e.values.map((v) => isUserKey(e.key) && UUID_RE.test(v)
              ? <Link key={v} className="text-primary underline" href={`/admin/users/${v}`}>{v.slice(0, 8)}</Link>
              : <span key={v}>{v}</span>)}
          </dd>
        </div>
      ))}
    </dl>
  );
}

/** Open flags grouped by type. */
export function FraudAlertsList({ flags }: { flags: FlagView[] }) {
  if (flags.length === 0) return <Card><EmptyState title="Không có cảnh báo đang mở" /></Card>;
  const groups = Map.groupBy(flags, (f) => f.type);
  return (
    <div className="flex flex-col gap-6">
      {[...groups].map(([type, list]) => (
        <section key={type} aria-label={flagLabel(type)}>
          <h2 className="mb-2 text-lg font-semibold text-text">{flagLabel(type)} <Badge tone="warning">{list.length}</Badge></h2>
          <div className="flex flex-col gap-3">
            {list.map((f) => (
              <Card key={f.id} className="p-4">
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <div>
                    {f.userId ? <Link className="font-medium text-primary underline" href={`/admin/users/${f.userId}`}>{f.email || f.userId}</Link> : "Không gắn người dùng"}
                    <span className="ml-2 text-xs text-text-muted">{formatDateTime(f.createdAt)} · điểm {f.score}</span>
                    {f.locked && <Badge tone="danger" className="ml-2">Đã khóa</Badge>}
                  </div>
                  <FlagActions flagId={f.id} userId={f.userId} type={f.type} locked={f.locked} />
                </div>
                <Evidence evidence={f.evidence} />
              </Card>
            ))}
          </div>
        </section>
      ))}
    </div>
  );
}
