import Link from "next/link";
import { Button } from "@/components/ui/button";
import { Input, Label, Select } from "@/components/ui/input";

type SP = Record<string, string | string[] | undefined>;
const first = (v: string | string[] | undefined) => (Array.isArray(v) ? v[0] : v) ?? "";

/** GET form for the risk tab: q (email), level, locked, kyc. */
export function RiskFilters({ searchParams }: { searchParams: SP }) {
  return (
    <form method="get" className="mb-4 flex flex-wrap items-end gap-3 rounded-2xl border border-border bg-surface p-4">
      <input type="hidden" name="tab" value="risk" />
      <div className="flex flex-col gap-1">
        <Label htmlFor="r-q">Email</Label>
        <Input id="r-q" name="q" maxLength={64} placeholder="Tìm theo email" defaultValue={first(searchParams.q)} />
      </div>
      <div className="flex flex-col gap-1">
        <Label htmlFor="r-level">Mức rủi ro</Label>
        <Select id="r-level" name="level" defaultValue={first(searchParams.level)}>
          <option value="">Tất cả</option><option value="high">Cao</option><option value="medium">Trung bình</option><option value="low">Thấp</option>
        </Select>
      </div>
      <div className="flex flex-col gap-1">
        <Label htmlFor="r-locked">Khóa</Label>
        <Select id="r-locked" name="locked" defaultValue={first(searchParams.locked)}>
          <option value="">Tất cả</option><option value="1">Đã khóa</option>
        </Select>
      </div>
      <div className="flex flex-col gap-1">
        <Label htmlFor="r-kyc">KYC</Label>
        <Select id="r-kyc" name="kyc" defaultValue={first(searchParams.kyc)}>
          <option value="">Tất cả</option><option value="pending">Chờ duyệt</option><option value="verified">Đã xác minh</option><option value="rejected">Từ chối</option>
        </Select>
      </div>
      <Button type="submit">Lọc</Button>
      <Button asChild variant="outline"><Link href="/admin/users?tab=risk">Đặt lại</Link></Button>
    </form>
  );
}
