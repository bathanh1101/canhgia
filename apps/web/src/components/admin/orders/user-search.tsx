"use client";

import { useState, useTransition } from "react";
import { searchUsers } from "@/app/admin/orders/actions";
import { notifyResult } from "@/components/admin-kit/notify-result";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import type { UserRef } from "./orders-query";

/** Search by email fragment or numeric short_id; calls onPick with the chosen user. */
export function UserSearch({ onPick }: { onPick: (u: UserRef) => void }) {
  const [q, setQ] = useState("");
  const [results, setResults] = useState<UserRef[] | null>(null);
  const [pending, start] = useTransition();

  const run = () =>
    start(async () => {
      try {
        const r = await searchUsers(q);
        if (r.ok) setResults(r.data ?? []);
        else notifyResult(r);
      } catch {
        notifyResult({ ok: false, error: "Đã có lỗi xảy ra. Vui lòng thử lại." });
      }
    });

  return (
    <div className="space-y-3">
      <div className="flex gap-2">
        <Input
          aria-label="Tìm người dùng" placeholder="Email hoặc mã số user" value={q} maxLength={64}
          onChange={(e) => setQ(e.target.value)}
          onKeyDown={(e) => { if (e.key === "Enter") { e.preventDefault(); run(); } }}
        />
        <Button type="button" onClick={run} disabled={pending || q.trim().length < 2}>Tìm</Button>
      </div>
      {results && results.length === 0 && <p className="text-sm text-text-muted">Không tìm thấy người dùng.</p>}
      <ul className="space-y-1">
        {results?.map((u) => (
          <li key={u.id}>
            <button
              type="button" onClick={() => onPick(u)}
              className="w-full rounded-lg border border-border px-3 py-2 text-left text-sm hover:bg-bg"
            >
              {u.email ?? "(không có email)"} <span className="text-text-muted">· #{u.short_id}</span>
            </button>
          </li>
        ))}
      </ul>
    </div>
  );
}
