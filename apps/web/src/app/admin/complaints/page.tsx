import { PageHeader } from "@/components/admin-kit/page-header";
import { EmptyState } from "@/components/admin-kit/states";
import { requireAdmin } from "@/lib/admin/require-admin";

export const dynamic = "force-dynamic";

// Placeholder: replaced by phase 08/09 (they own this file).
export default async function Page() {
  await requireAdmin();
  return (
    <>
      <PageHeader title="Xử lý khiếu nại" />
      <EmptyState title="Đang phát triển" />
    </>
  );
}
