import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_session_provider.dart';
import '../../../core/supabase/postgrest_error_mapper.dart';
import '../data/withdrawal.dart';
import 'uuid_v4.dart';
import 'withdraw_providers.dart';

class WithdrawFormState {
  const WithdrawFormState({
    this.amount = 0,
    this.bankAccountId,
    this.submitting = false,
    this.result,
    this.resultAmount,
  });

  final int amount;
  final String? bankAccountId;
  final bool submitting;
  final WithdrawalResult? result;

  /// Amount of the created withdrawal as the server knows it (not the possibly edited form value).
  final int? resultAmount;

  WithdrawFormState copyWith({int? amount, String? bankAccountId, bool? submitting, WithdrawalResult? result, int? resultAmount}) =>
      WithdrawFormState(
        amount: amount ?? this.amount,
        bankAccountId: bankAccountId ?? this.bankAccountId,
        submitting: submitting ?? this.submitting,
        result: result ?? this.result,
        resultAmount: resultAmount ?? this.resultAmount,
      );
}

/// The attempt whose outcome the client does not know yet (network/timeout after sending).
typedef PendingWithdrawal = ({String requestKey, int amount, String bankAccountId});

/// Survives closing the withdraw screen. Cleared on a terminal server response or a user change.
class PendingWithdrawalNotifier extends Notifier<PendingWithdrawal?> {
  @override
  PendingWithdrawal? build() {
    ref.watch(currentUserIdProvider);
    return null;
  }

  void set(PendingWithdrawal? v) => state = v;
}

final pendingWithdrawalProvider = NotifierProvider<PendingWithdrawalNotifier, PendingWithdrawal?>(PendingWithdrawalNotifier.new);

/// A definite answer from the server means the key can be dropped; anything else (offline, timeout,
/// unparsable) may have committed, so the key is kept and looked up before a new attempt.
bool _isUnknownOutcome(Object e) => const {'network', 'unknown', ''}.contains(AppFailure.from(e).code);

class WithdrawForm extends Notifier<WithdrawFormState> {
  @override
  WithdrawFormState build() => const WithdrawFormState();

  void setAmount(int v) => state = state.copyWith(amount: v);
  void selectBank(String id) => state = state.copyWith(bankAccountId: id);

  /// Throws the backend failure on error (caller maps it); ignores re-entrant calls.
  Future<WithdrawalResult?> submit(String pinToken) async {
    final bankId = state.bankAccountId;
    if (state.submitting || bankId == null || state.amount <= 0) return null;
    state = state.copyWith(submitting: true);
    final pending = ref.read(pendingWithdrawalProvider.notifier);
    final repo = ref.read(withdrawRepositoryProvider);
    try {
      var p = ref.read(pendingWithdrawalProvider);
      if (p != null) {
        // Earlier attempt with unknown outcome: it may have been committed. Show it instead of creating another.
        final found = await repo.withdrawalByKey(p.requestKey);
        if (found != null) {
          pending.set(null);
          return _done((id: found.id, status: found.status), found.amount);
        }
        // Not committed: same key is only safe to replay with identical parameters.
        if (p.amount != state.amount || p.bankAccountId != bankId) p = null;
      }
      p ??= (requestKey: uuidV4(), amount: state.amount, bankAccountId: bankId);
      pending.set(p);
      final r = await repo.request(requestKey: p.requestKey, amount: p.amount, bankAccountId: p.bankAccountId, pinToken: pinToken);
      pending.set(null);
      return _done(r, p.amount);
    } on Object catch (e) {
      if (!_isUnknownOutcome(e)) pending.set(null);
      if (ref.mounted) state = state.copyWith(submitting: false);
      rethrow;
    }
  }

  WithdrawalResult _done(WithdrawalResult r, int amount) {
    if (ref.mounted) state = state.copyWith(submitting: false, result: r, resultAmount: amount);
    return r;
  }
}

final withdrawFormProvider = NotifierProvider.autoDispose<WithdrawForm, WithdrawFormState>(WithdrawForm.new);
