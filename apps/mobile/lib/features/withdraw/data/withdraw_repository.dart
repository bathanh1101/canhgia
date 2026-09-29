import 'package:supabase_flutter/supabase_flutter.dart';

import 'bank_models.dart';
import 'withdrawal.dart';

/// Banks, bank accounts, settings and the money-out RPC.
class WithdrawRepository {
  WithdrawRepository(this._db);
  final SupabaseClient _db;

  Future<List<BankAccount>> bankAccounts(String uid) async {
    final rows = await _db.from('bank_accounts').select(BankAccount.columns).eq('user_id', uid).order('created_at');
    return [for (final r in rows) BankAccount.fromJson(r)];
  }

  Future<List<Bank>> banks() async {
    final rows = await _db.from('banks').select(Bank.columns).order('sort');
    return [for (final r in rows) Bank.fromJson(r)];
  }

  Future<PublicSettings> publicSettings() async {
    final s = await _db.rpc('get_public_settings');
    return s is Map<String, dynamic> ? PublicSettings.fromJson(s) : const PublicSettings();
  }

  Future<List<Withdrawal>> withdrawals(String uid, {int limit = 50}) async {
    final rows = await _db
        .from('withdrawals')
        .select(Withdrawal.columns)
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(limit);
    return [for (final r in rows) Withdrawal.fromJson(r)];
  }

  /// [requestKey] is generated once per form and reused on retry (server idempotency).
  Future<WithdrawalResult> request({
    required String requestKey,
    required int amount,
    required String bankAccountId,
    required String pinToken,
  }) async {
    final rows = await _db.rpc('request_withdrawal', params: {
      'p_request_key': requestKey,
      'p_amount': amount,
      'p_bank_account_id': bankAccountId,
      'p_pin_token': pinToken,
    });
    final r = (rows as List).first as Map<String, dynamic>;
    return (id: r['withdrawal_id'] as String, status: r['status'] as String);
  }
}
