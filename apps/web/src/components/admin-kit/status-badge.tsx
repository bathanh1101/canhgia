import { Badge } from "@/components/ui/badge";
import { statusView } from "@/lib/admin/status";

export function StatusBadge({ status }: { status: string | null | undefined }) {
  const { label, tone } = statusView(status);
  return <Badge tone={tone}>{label}</Badge>;
}
