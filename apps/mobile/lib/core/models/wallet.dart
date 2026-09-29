/// Row of `wallets` (all VND bigint).
class Wallet {
  const Wallet({
    required this.availableVnd,
    required this.pendingVnd,
    required this.heldVnd,
    required this.totalEarnedVnd,
  });

  final int availableVnd;
  final int pendingVnd;
  final int heldVnd;
  final int totalEarnedVnd;

  /// "Chờ duyệt" on the wallet screen = platform-pending + anti-clawback hold.
  int get awaitingVnd => pendingVnd + heldVnd;

  factory Wallet.fromJson(Map<String, dynamic> j) => Wallet(
        availableVnd: (j['available_vnd'] as num?)?.toInt() ?? 0,
        pendingVnd: (j['pending_vnd'] as num?)?.toInt() ?? 0,
        heldVnd: (j['held_vnd'] as num?)?.toInt() ?? 0,
        totalEarnedVnd: (j['total_earned_vnd'] as num?)?.toInt() ?? 0,
      );
}
