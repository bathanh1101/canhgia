import { AlertTriangle, Inbox } from "lucide-react";
import type { ReactNode } from "react";

export function EmptyState({ title = "Chưa có dữ liệu", description }: { title?: string; description?: string }) {
  return (
    <div className="flex flex-col items-center gap-2 py-12 text-center text-text-muted">
      <Inbox size={32} aria-hidden />
      <p className="font-medium text-text-2">{title}</p>
      {description && <p className="text-sm">{description}</p>}
    </div>
  );
}

export function ErrorState({ message, action }: { message: string; action?: ReactNode }) {
  return (
    <div role="alert" className="flex flex-col items-center gap-2 rounded-2xl bg-danger-tint py-10 text-center text-danger">
      <AlertTriangle size={32} aria-hidden />
      <p className="font-medium">{message}</p>
      {action}
    </div>
  );
}
