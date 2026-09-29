export interface WithdrawalRow {
  id: string;
  createdAt: string | null;
  userId: string;
  email: string;
  kycName: string | null;
  amount: number;
  status: "pending" | "processing" | "paid" | "rejected";
  bankName: string;
  bankBin: string;
  accountNumber: string;
  accountName: string;
  bankAccountId: string;
  bankVerified: boolean;
  snapshotRisk: string;
  liveRiskScore: number | null;
  liveRiskLevel: string | null;
  flagCount: number;
  claimedBy: string | null;
  claimedByEmail: string | null;
  claimedAt: string | null;
  paidByEmail: string | null;
  paidAt: string | null;
  transferRef: string | null;
  rejectReason: string | null;
}

/** Per-row outcome of a bulk admin RPC (`ok` or an admin error code). */
export interface RowResult {
  id: string;
  ok: boolean;
  error?: string | null;
}
