import 'package:supabase_flutter/supabase_flutter.dart';

class Voucher {
  const Voucher({
    required this.id,
    required this.merchantId,
    this.code,
    this.title,
    this.description,
    this.discountText,
    this.url,
    this.endsAt,
  });

  final int id;
  final String merchantId;
  final String? code;
  final String? title;
  final String? description;
  final String? discountText;
  final String? url;
  final DateTime? endsAt;

  String get headline {
    for (final s in [discountText, title, code]) {
      if (s != null && s.trim().isNotEmpty) return s.trim();
    }
    return 'Voucher';
  }

  bool get hasCode => code != null && code!.trim().isNotEmpty;

  factory Voucher.fromJson(Map<String, dynamic> j) => Voucher(
        id: (j['id'] as num).toInt(),
        merchantId: j['merchant_id'] as String,
        code: j['code'] as String?,
        title: j['title'] as String?,
        description: j['description'] as String?,
        discountText: j['discount_text'] as String?,
        url: j['url'] as String?,
        endsAt: j['ends_at'] == null ? null : DateTime.tryParse(j['ends_at'] as String),
      );
}

/// Filter chip keys of the vouchers screen: all / saved only / a merchant id.
const voucherFilterAll = '';
const voucherFilterSaved = 'saved';

List<Voucher> filterVouchers(List<Voucher> all, String filter, Set<int> savedIds) =>
    filter == voucherFilterSaved ? [for (final v in all) if (savedIds.contains(v.id)) v] : all;

const _cols = 'id,merchant_id,code,title,description,discount_text,url,ends_at';

class VoucherRepository {
  VoucherRepository(this._db);
  final SupabaseClient _db;

  /// Active vouchers (started, not expired), soonest expiry first; [merchantId] filters server-side.
  Future<List<Voucher>> active({String? merchantId, int limit = 100}) async {
    final now = DateTime.now().toUtc().toIso8601String();
    var q = _db.from('vouchers').select(_cols).or('ends_at.is.null,ends_at.gt.$now').or('starts_at.is.null,starts_at.lte.$now');
    if (merchantId != null) q = q.eq('merchant_id', merchantId);
    final rows = await q.order('ends_at', ascending: true, nullsFirst: false).limit(limit);
    return [for (final r in rows) Voucher.fromJson(r)];
  }

  Future<Set<int>> savedIds(String uid) async {
    final rows = await _db.from('saved_vouchers').select('voucher_id').eq('user_id', uid);
    return {for (final r in rows) (r['voucher_id'] as num).toInt()};
  }

  Future<void> save(String uid, int voucherId) =>
      _db.from('saved_vouchers').upsert({'user_id': uid, 'voucher_id': voucherId}, onConflict: 'user_id,voucher_id');

  Future<void> unsave(String uid, int voucherId) =>
      _db.from('saved_vouchers').delete().eq('user_id', uid).eq('voucher_id', voucherId);
}
