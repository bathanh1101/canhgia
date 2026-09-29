import { Badge } from "@/components/ui/badge";
import { RISK_LABEL, riskTone } from "./withdrawal-state";

/** Snapshot risk (at request time) and, when different, the live `user_risk` level. */
export function RiskBadge({ snapshot, live, score }: { snapshot: string; live?: string | null; score?: number | null }) {
  const label = (l: string) => RISK_LABEL[l as keyof typeof RISK_LABEL] ?? l;
  return (
    <span className="flex flex-col items-start gap-1">
      <Badge tone={riskTone(snapshot)}>Lúc rút: {label(snapshot)}</Badge>
      {live && (
        <Badge tone={riskTone(live)}>Hiện tại: {label(live)}{score != null ? ` (${score})` : ""}</Badge>
      )}
    </span>
  );
}
