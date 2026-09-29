import Link from "next/link";
import { notFound } from "next/navigation";
import { PageHeader } from "@/components/admin-kit/page-header";
import { ErrorState } from "@/components/admin-kit/states";
import { ComplaintDetail } from "@/components/admin/complaints/complaint-detail";
import { Button } from "@/components/ui/button";
import { requireAdmin } from "@/lib/admin/require-admin";
import { loadComplaint } from "../load-complaint";
import { reportIdSchema } from "../schemas";

export const dynamic = "force-dynamic";

export default async function Page({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const { supabase, adminId } = await requireAdmin();
  const n = reportIdSchema.safeParse(Number(id));
  if (!n.success) notFound();
  const data = await loadComplaint(supabase, n.data);
  if (data === null) notFound();
  if ("error" in data) return <ErrorState message="Không tải được khiếu nại." />;
  return (
    <>
      <PageHeader title="Chi tiết khiếu nại" actions={<Button asChild variant="outline"><Link href="/admin/complaints">Quay lại</Link></Button>} />
      <ComplaintDetail d={data} adminId={adminId} />
    </>
  );
}
