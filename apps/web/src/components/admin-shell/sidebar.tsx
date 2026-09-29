"use client";

import { Banknote, LayoutDashboard, MessageSquareWarning, Percent, Receipt, ShieldAlert } from "lucide-react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { ADMIN_NAV } from "@/lib/admin/nav";
import { cn } from "@/lib/utils";

const ICONS = {
  "layout-dashboard": LayoutDashboard,
  receipt: Receipt,
  percent: Percent,
  banknote: Banknote,
  "shield-alert": ShieldAlert,
  "message-square-warning": MessageSquareWarning,
} as const;

export function Sidebar() {
  const pathname = usePathname();
  return (
    <nav aria-label="Điều hướng quản trị" className="flex w-64 shrink-0 flex-col gap-1 border-r border-border bg-surface p-4">
      <div className="mb-4 px-3 text-lg font-bold text-primary">CanhGia Admin</div>
      {ADMIN_NAV.map(({ href, label, icon }) => {
        const Icon = ICONS[icon];
        const active = pathname === href || pathname.startsWith(`${href}/`);
        return (
          <Link
            key={href}
            href={href}
            aria-current={active ? "page" : undefined}
            className={cn(
              "flex items-center gap-3 rounded-lg px-3 py-2 text-sm font-medium",
              active ? "bg-primary-tint text-primary" : "text-text-2 hover:bg-bg",
            )}
          >
            <Icon size={18} aria-hidden />
            {label}
          </Link>
        );
      })}
    </nav>
  );
}
