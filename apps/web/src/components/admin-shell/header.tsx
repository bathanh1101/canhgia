import { LogOut } from "lucide-react";
import { signOut } from "@/app/admin/actions";
import { Button } from "@/components/ui/button";

export function AdminHeader({ email }: { email: string }) {
  return (
    <div className="flex h-14 items-center justify-end gap-3 border-b border-border bg-surface px-6">
      <span className="text-sm text-text-muted">{email}</span>
      <form action={signOut}>
        <Button type="submit" variant="ghost" size="sm"><LogOut size={16} aria-hidden />Đăng xuất</Button>
      </form>
    </div>
  );
}
