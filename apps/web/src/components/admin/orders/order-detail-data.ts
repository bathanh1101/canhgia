import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@/lib/supabase/database.types";

type Tables = Database["public"]["Tables"];
export type LedgerLine = Pick<Tables["wallet_ledger"]["Row"], "id" | "entry_type" | "amount_vnd" | "created_at" | "available_at" | "note">;
export type ClickInfo = Pick<Tables["clicks"]["Row"], "id" | "source" | "status" | "created_at" | "utm_content" | "merchant_id">;

export interface OrderDetail {
  raw: unknown;
  click: ClickInfo | null;
  ledger: LedgerLine[];
}

/** Raw AT payload, originating click and wallet ledger lines for one order (admin RLS). */
export async function loadOrderDetail(
  sb: SupabaseClient<Database>, orderId: string, clickId: number | null,
): Promise<OrderDetail> {
  const [raw, click, ledger] = await Promise.all([
    sb.from("order_raw").select("raw").eq("order_id", orderId).maybeSingle(),
    clickId === null
      ? Promise.resolve({ data: null, error: null })
      : sb.from("clicks").select("id,source,status,created_at,utm_content,merchant_id").eq("id", clickId).maybeSingle(),
    sb.from("wallet_ledger").select("id,entry_type,amount_vnd,created_at,available_at,note")
      .eq("order_id", orderId).order("id", { ascending: true }),
  ]);
  const err = raw.error ?? click.error ?? ledger.error;
  if (err) throw new Error(err.message);
  return { raw: raw.data?.raw ?? null, click: click.data, ledger: ledger.data ?? [] };
}
