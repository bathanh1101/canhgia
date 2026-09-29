import 'package:supabase_flutter/supabase_flutter.dart';

import '../../kyc/data/photo.dart';
import '../../withdraw/application/uuid_v4.dart';

/// Row of `missing_order_reports` (own).
class MissingReport {
  const MissingReport({
    required this.publicCode,
    required this.merchantId,
    required this.orderCode,
    required this.status,
    required this.createdAt,
  });

  static const columns = 'public_code,merchant_id,order_code,status,created_at';

  final String publicCode;
  final String merchantId;
  final String orderCode;
  final String status;
  final DateTime createdAt;

  factory MissingReport.fromJson(Map<String, dynamic> j) => MissingReport(
        publicCode: j['public_code'] as String,
        merchantId: j['merchant_id'] as String,
        orderCode: j['order_code'] as String,
        status: j['status'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
      );

  /// Key understood by `StatusPill.forStatus` (open reports show "Đang kiểm tra").
  String get pillKey => switch (status) {
        'approved' => 'approved',
        'rejected' => 'rejected',
        _ => 'checking',
      };
}

class MissingOrderRepository {
  MissingOrderRepository(this._db, this._uploader);
  final SupabaseClient _db;
  final PhotoUploader _uploader;

  Future<List<MissingReport>> reports(String uid, {int limit = 20}) async {
    final rows = await _db
        .from('missing_order_reports')
        .select(MissingReport.columns)
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(limit);
    return [for (final r in rows) MissingReport.fromJson(r)];
  }

  /// Uploads screenshots to `complaints/<uid>/<uuid>.<ext>` then files the report; returns the `KN-xxxxxx` code.
  Future<String> submit({
    required String uid,
    required String merchantId,
    required String orderCode,
    required DateTime purchasedOn,
    required int valueVnd,
    required List<PickedPhoto> photos,
  }) async {
    final paths = <String>[
      for (final p in photos) await _uploader.upload(bucket: 'complaints', uid: uid, name: uuidV4(), photo: p),
    ];
    final d = purchasedOn;
    final day = '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final code = await _db.rpc('submit_missing_order', params: {
      'p_merchant_id': merchantId,
      'p_order_code': orderCode.trim(),
      'p_purchased_on': day,
      'p_value': valueVnd,
      'p_image_paths': paths,
    });
    return '$code';
  }
}
