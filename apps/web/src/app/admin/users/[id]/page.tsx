import Link from "next/link";
import { notFound } from "next/navigation";
import { PageHeader } from "@/components/admin-kit/page-header";
import { ErrorState } from "@/components/admin-kit/states";
import { AdjustWalletDialog } from "@/components/admin/users/adjust-wallet-dialog";
import { KycReviewPanel } from "@/components/admin/users/kyc-review-panel";
import { LockDialog } from "@/components/admin/users/lock-dialog";
import { UserProfileSections } from "@/components/admin/users/user-profile-sections";
import { Button } from "@/components/ui/button";
import { requireAdmin } from "@/lib/admin/require-admin";
import { userIdSchema } from "../schemas";
import { loadUserProfile } from "../load-user-profile";

export const dynamic = "force-dynamic";

export default async function Page({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const { supabase } = await requireAdmin();
  if (!userIdSchema.safeParse(id).success) notFound();
  const result = await loadUserProfile(supabase, id);
  if (result === null) notFound();
  if ("error" in result) return <ErrorState message="Không tải được hồ sơ người dùng." />;
  const { data, kyc } = result;
  const locked = data.profile.locked_at !== null;

  return (
    <>
      <PageHeader
        title={data.profile.email ?? "Người dùng"}
        description={`ID ${id}`}
        actions={
          <>
            <Button asChild variant="outline"><Link href="/admin/users">Quay lại</Link></Button>
            <AdjustWalletDialog userId={id} trigger={<Button variant="outline">Điều chỉnh ví</Button>} />
            <LockDialog userId={id} locked={locked} trigger={<Button variant={locked ? "default" : "destructive"}>{locked ? "Mở khóa" : "Khóa tài khoản"}</Button>} />
          </>
        }
      />
      <div className="mb-6"><KycReviewPanel userId={id} kyc={kyc} /></div>
      <UserProfileSections d={data} />
    </>
  );
}
