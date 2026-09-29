export const FLAG_LABELS: Record<string, string> = {
  multi_account_device: "Nhiều tài khoản / 1 thiết bị",
  abnormal_clicks: "Click bất thường",
  self_referral: "Tự mua qua link giới thiệu",
  shared_identity: "Trùng CCCD",
  shared_bank_account: "Trùng tài khoản ngân hàng",
  order_claim_conflict: "Tranh chấp đơn hàng",
  negative_balance_risk: "Nguy cơ âm ví",
};

export const flagLabel = (type: string) => FLAG_LABELS[type] ?? type;

export interface EvidenceEntry { key: string; values: string[] }

const scalar = (v: unknown): string => (typeof v === "object" && v !== null ? JSON.stringify(v) : String(v));

/** Flattens the flag `evidence` JSON (object of scalars/arrays) for display. Non-objects yield []. */
export function evidenceEntries(evidence: unknown): EvidenceEntry[] {
  if (typeof evidence !== "object" || evidence === null || Array.isArray(evidence)) return [];
  return Object.entries(evidence).map(([key, v]) => ({ key, values: Array.isArray(v) ? v.map(scalar) : [scalar(v)] }));
}

export const isUserKey = (key: string) => key === "user_id" || key.endsWith("user_ids") || key === "referrer_id" || key === "claimed_by";
export const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
