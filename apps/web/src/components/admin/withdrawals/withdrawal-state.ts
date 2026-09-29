import type { RowResult, WithdrawalRow } from "./types";

export const RECLAIM_AFTER_MIN = 30;

export type ClaimState = "claimable" | "mine" | "other" | "closed";

export function minutesSince(iso: string | null, now: number): number {
  if (!iso) return 0;
  const t = new Date(iso).getTime();
  return Number.isNaN(t) ? 0 : Math.max(0, Math.floor((now - t) / 60000));
}

/**
 * claimable = pending, or another admin's claim older than 30 min (SQL re-claim rule)
 * mine = I hold the claim (open the dialog without re-claiming); other = fresh claim by someone else.
 */
export function claimState(row: Pick<WithdrawalRow, "status" | "claimedBy" | "claimedAt">, adminId: string, now: number): ClaimState {
  if (row.status === "pending") return "claimable";
  if (row.status !== "processing") return "closed";
  if (row.claimedBy === adminId) return "mine";
  return minutesSince(row.claimedAt, now) >= RECLAIM_AFTER_MIN ? "claimable" : "other";
}

export type RiskTone = "success" | "warning" | "danger";

/** Mirrors refresh_risk_scores: <30 low, <60 medium, otherwise high. */
export function riskLevelFromScore(score: number): "low" | "medium" | "high" {
  return score < 30 ? "low" : score < 60 ? "medium" : "high";
}

export const RISK_LABEL = { low: "Thấp", medium: "Trung bình", high: "Cao" } as const;
export const riskTone = (level: string | null | undefined): RiskTone =>
  level === "high" ? "danger" : level === "medium" ? "warning" : "success";

/** High risk (snapshot or live) rows never enter bulk actions. */
export function isHighRisk(row: Pick<WithdrawalRow, "snapshotRisk" | "liveRiskLevel">): boolean {
  return row.snapshotRisk === "high" || row.liveRiskLevel === "high";
}

export type BulkKind = "claim" | "pay" | "reject";

export function bulkEligible(row: WithdrawalRow, kind: BulkKind, adminId: string, now: number): boolean {
  if (isHighRisk(row)) return false;
  const state = claimState(row, adminId, now);
  return kind === "claim" ? state === "claimable" : state === "mine";
}

export function maskAccount(n: string): string {
  return n.length <= 4 ? "****" : `${"*".repeat(Math.min(n.length - 4, 6))}${n.slice(-4)}`;
}

export function summarizeResults(results: RowResult[]): { ok: number; failed: number } {
  const ok = results.filter((r) => r.ok).length;
  return { ok, failed: results.length - ok };
}

/** Memo carried in the QR: CANHGIA + first 8 chars of the id (fits the 25-char memo cap). */
export const transferMemo = (id: string) => `CANHGIA ${id.replaceAll("-", "").slice(0, 8)}`;
