import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/withdrawal.dart';
import 'uuid_v4.dart';
import 'withdraw_providers.dart';

class WithdrawFormState {
  const WithdrawFormState({
    required this.requestKey,
    this.amount = 0,
    this.bankAccountId,
    this.submitting = false,
    this.result,
  });

  final String requestKey;
  final int amount;
  final String? bankAccountId;
  final bool submitting;
  final WithdrawalResult? result;

  WithdrawFormState copyWith({int? amount, String? bankAccountId, bool? submitting, WithdrawalResult? result}) =>
      WithdrawFormState(
        requestKey: requestKey,
        amount: amount ?? this.amount,
        bankAccountId: bankAccountId ?? this.bankAccountId,
        submitting: submitting ?? this.submitting,
        result: result ?? this.result,
      );
}

/// One `request_key` per form: a retry after a network error replays the same request
/// server-side instead of creating a second withdrawal.
class WithdrawForm extends Notifier<WithdrawFormState> {
  @override
  WithdrawFormState build() => WithdrawFormState(requestKey: uuidV4());

  void setAmount(int v) => state = state.copyWith(amount: v);
  void selectBank(String id) => state = state.copyWith(bankAccountId: id);

  /// Throws the backend failure on error (caller maps it); ignores re-entrant calls.
  Future<WithdrawalResult?> submit(String pinToken) async {
    final bankId = state.bankAccountId;
    if (state.submitting || bankId == null || state.amount <= 0) return null;
    state = state.copyWith(submitting: true);
    try {
      final r = await ref.read(withdrawRepositoryProvider).request(
            requestKey: state.requestKey,
            amount: state.amount,
            bankAccountId: bankId,
            pinToken: pinToken,
          );
      state = state.copyWith(submitting: false, result: r);
      return r;
    } on Object {
      state = state.copyWith(submitting: false);
      rethrow;
    }
  }
}

final withdrawFormProvider = NotifierProvider.autoDispose<WithdrawForm, WithdrawFormState>(WithdrawForm.new);
