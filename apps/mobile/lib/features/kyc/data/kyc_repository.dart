import 'package:supabase_flutter/supabase_flutter.dart';

import '../../withdraw/application/uuid_v4.dart';
import 'photo.dart';

/// `kyc_profiles` row (own). `status`: pending | verified | rejected.
class KycProfile {
  const KycProfile({required this.status, required this.fullName, required this.last4, this.rejectReason, this.submittedAt});

  static const columns = 'status,full_name,id_number_last4,reject_reason,submitted_at';

  final String status;
  final String fullName;
  final String last4;
  final String? rejectReason;
  final DateTime? submittedAt;

  bool get isVerified => status == 'verified';
  bool get isPending => status == 'pending';
  bool get isRejected => status == 'rejected';

  factory KycProfile.fromJson(Map<String, dynamic> j) => KycProfile(
        status: j['status'] as String,
        fullName: (j['full_name'] as String?) ?? '',
        last4: (j['id_number_last4'] as String?) ?? '',
        rejectReason: j['reject_reason'] as String?,
        submittedAt: j['submitted_at'] == null ? null : DateTime.parse(j['submitted_at'] as String),
      );
}

class KycRepository {
  KycRepository(this._db, this._uploader);
  final SupabaseClient _db;
  final PhotoUploader _uploader;

  Future<KycProfile?> profile(String uid) async {
    final row = await _db.from('kyc_profiles').select(KycProfile.columns).eq('user_id', uid).maybeSingle();
    return row == null ? null : KycProfile.fromJson(row);
  }

  /// Uploads both photos (private `kyc` bucket) and then calls `submit_kyc` with their paths.
  Future<void> submit({
    required String uid,
    required String fullName,
    required String idNumber,
    required PickedPhoto front,
    required PickedPhoto back,
  }) async {
    final id = uuidV4();
    final f = await _uploader.upload(bucket: 'kyc', uid: uid, name: 'front-$id', photo: front);
    final b = await _uploader.upload(bucket: 'kyc', uid: uid, name: 'back-$id', photo: back);
    await _db.rpc('submit_kyc', params: {'p_full_name': fullName, 'p_id_number': idNumber, 'p_front_path': f, 'p_back_path': b});
  }

  Future<String> addBank({required String bankBin, required String accountNumber, required String accountName}) async {
    final id = await _db.rpc('add_bank_account', params: {
      'p_bank_bin': bankBin,
      'p_account_number': accountNumber,
      'p_account_name': accountName,
    });
    return '$id';
  }
}
