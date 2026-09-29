import Link from "next/link";
import { pageCount, pageWindow, withPage } from "@/lib/admin/pagination";
import { cn } from "@/lib/utils";

type SP = Record<string, string | string[] | undefined>;

/** Server pagination: links keep the current filters. `total` = full row count (from `count: 'exact'`). */
export function Pagination({
  total, page, size, searchParams, basePath = "",
}: { total: number; page: number; size: number; searchParams: SP; basePath?: string }) {
  const pages = pageCount(total, size);
  if (pages <= 1) return null;
  const item = "rounded-lg border border-border px-3 py-1.5 text-sm";
  return (
    <nav aria-label="Phân trang" className="mt-4 flex flex-wrap items-center justify-between gap-2">
      <p className="text-sm text-text-muted">{total.toLocaleString("vi-VN")} bản ghi</p>
      <ul className="flex items-center gap-1">
        {pageWindow(page, pages).map((n, i) =>
          n === null ? (
            <li key={`e${i}`} className="px-1 text-text-muted">…</li>
          ) : (
            <li key={n}>
              <Link
                href={`${basePath}${withPage(searchParams, n)}`}
                aria-current={n === page ? "page" : undefined}
                className={cn(item, n === page ? "border-primary bg-primary text-white" : "bg-surface text-text-2 hover:bg-bg")}
              >
                {n}
              </Link>
            </li>
          ),
        )}
      </ul>
    </nav>
  );
}
