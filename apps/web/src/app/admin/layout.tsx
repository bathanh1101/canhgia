import { headers } from "next/headers";
import { AdminHeader } from "@/components/admin-shell/header";
import { Sidebar } from "@/components/admin-shell/sidebar";
import { Toaster } from "@/components/ui/sonner";
import { requireAdmin } from "@/lib/admin/require-admin";
import { isAdminAuthPath } from "@/lib/admin/public-paths";

export const dynamic = "force-dynamic";

export default async function AdminLayout({ children }: { children: React.ReactNode }) {
  const pathname = (await headers()).get("x-pathname"); // set by proxy.ts; missing → guarded (fail closed)
  if (isAdminAuthPath(pathname)) {
    return (<>{children}<Toaster /></>);
  }
  const { email } = await requireAdmin();
  return (
    <div className="flex min-h-screen bg-bg">
      <Sidebar />
      <div className="flex min-w-0 flex-1 flex-col">
        <AdminHeader email={email} />
        <main className="flex-1 p-6">{children}</main>
      </div>
      <Toaster />
    </div>
  );
}
