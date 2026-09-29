import Link from "next/link";
import { Button } from "@/components/ui/button";
import { Input, Label, Select } from "@/components/ui/input";

export interface Option { value: string; label: string }
type SP = Record<string, string | string[] | undefined>;

const first = (v: string | string[] | undefined) => (Array.isArray(v) ? v[0] : v) ?? "";

/**
 * GET form: state lives in the URL, so pages stay server components.
 * Field names: `merchant`, `status`, `from`, `to`, `q` (each rendered only when its prop is given).
 */
export function FilterBar({
  searchParams, merchants, statuses, dateRange, search, resetHref,
}: {
  searchParams: SP;
  merchants?: Option[];
  statuses?: Option[];
  dateRange?: boolean;
  search?: string; // placeholder for the free-text `q` input
  resetHref: string;
}) {
  return (
    <form method="get" className="mb-4 flex flex-wrap items-end gap-3 rounded-2xl border border-border bg-surface p-4">
      {search && (
        <div className="flex flex-col gap-1">
          <Label htmlFor="f-q">Tìm kiếm</Label>
          <Input id="f-q" name="q" maxLength={64} placeholder={search} defaultValue={first(searchParams.q)} />
        </div>
      )}
      {merchants && (
        <div className="flex flex-col gap-1">
          <Label htmlFor="f-merchant">Sàn</Label>
          <Select id="f-merchant" name="merchant" defaultValue={first(searchParams.merchant)}>
            <option value="">Tất cả</option>
            {merchants.map((o) => <option key={o.value} value={o.value}>{o.label}</option>)}
          </Select>
        </div>
      )}
      {statuses && (
        <div className="flex flex-col gap-1">
          <Label htmlFor="f-status">Trạng thái</Label>
          <Select id="f-status" name="status" defaultValue={first(searchParams.status)}>
            <option value="">Tất cả</option>
            {statuses.map((o) => <option key={o.value} value={o.value}>{o.label}</option>)}
          </Select>
        </div>
      )}
      {dateRange && (
        <>
          <div className="flex flex-col gap-1">
            <Label htmlFor="f-from">Từ ngày</Label>
            <Input id="f-from" type="date" name="from" defaultValue={first(searchParams.from)} />
          </div>
          <div className="flex flex-col gap-1">
            <Label htmlFor="f-to">Đến ngày</Label>
            <Input id="f-to" type="date" name="to" defaultValue={first(searchParams.to)} />
          </div>
        </>
      )}
      <Button type="submit">Lọc</Button>
      <Button asChild variant="outline"><Link href={resetHref}>Đặt lại</Link></Button>
    </form>
  );
}
