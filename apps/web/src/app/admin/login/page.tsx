import { redirect } from "next/navigation";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { signOut } from "../actions";
import { signInWithGoogle } from "./actions";
import { LoginForm } from "./login-form";

export const dynamic = "force-dynamic";

const NOTICES: Record<string, string> = {
  forbidden: "Không có quyền. Tài khoản này không phải quản trị viên.",
  oauth: "Đăng nhập Google không thành công. Vui lòng thử lại.",
};

export default async function AdminLoginPage({
  searchParams,
}: { searchParams: Promise<{ e?: string }> }) {
  const { e } = await searchParams;
  const notice = e && Object.hasOwn(NOTICES, e) ? NOTICES[e] : null;
  if (e && !notice) redirect("/admin/login");

  return (
    <main className="flex min-h-screen items-center justify-center bg-bg p-4">
      <Card className="w-full max-w-sm">
        <CardContent className="flex flex-col gap-5 p-8">
          <div>
            <h1 className="text-xl font-bold text-text">CanhGia Admin</h1>
            <p className="text-sm text-text-muted">Đăng nhập để quản trị hệ thống</p>
          </div>
          {notice && (
            <p role="alert" className="rounded-lg bg-danger-tint p-3 text-sm text-danger">{notice}</p>
          )}
          {e === "forbidden" && (
            <form action={signOut}>
              <Button type="submit" variant="outline" className="w-full">Đăng xuất</Button>
            </form>
          )}
          <form action={signInWithGoogle}>
            <Button type="submit" variant="outline" className="w-full">Đăng nhập với Google</Button>
          </form>
          <div className="flex items-center gap-3 text-xs text-text-muted">
            <span className="h-px flex-1 bg-border" />hoặc<span className="h-px flex-1 bg-border" />
          </div>
          <LoginForm />
        </CardContent>
      </Card>
    </main>
  );
}
