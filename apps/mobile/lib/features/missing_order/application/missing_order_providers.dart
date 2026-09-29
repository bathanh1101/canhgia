import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_session_provider.dart';
import '../../../core/supabase/postgrest_error_mapper.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../kyc/application/kyc_providers.dart';
import '../../kyc/data/photo.dart';
import '../data/missing_order_repository.dart';
import 'missing_order_validation.dart';

final missingOrderRepositoryProvider = Provider<MissingOrderRepository>(
  (ref) => MissingOrderRepository(ref.watch(supabaseProvider), ref.watch(photoUploaderProvider)),
);

final myReportsProvider = FutureProvider.autoDispose<List<MissingReport>>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  return uid == null ? const [] : ref.watch(missingOrderRepositoryProvider).reports(uid);
});

class MissingOrderFormState {
  const MissingOrderFormState({
    this.merchantId,
    this.orderCode = '',
    this.purchasedOn,
    this.valueVnd = 0,
    this.photos = const [],
    this.submitting = false,
  });

  final String? merchantId;
  final String orderCode;
  final DateTime? purchasedOn;
  final int valueVnd;
  final List<PickedPhoto> photos;
  final bool submitting;

  MissingOrderFormState copyWith({
    String? merchantId,
    String? orderCode,
    DateTime? purchasedOn,
    int? valueVnd,
    List<PickedPhoto>? photos,
    bool? submitting,
  }) =>
      MissingOrderFormState(
        merchantId: merchantId ?? this.merchantId,
        orderCode: orderCode ?? this.orderCode,
        purchasedOn: purchasedOn ?? this.purchasedOn,
        valueVnd: valueVnd ?? this.valueVnd,
        photos: photos ?? this.photos,
        submitting: submitting ?? this.submitting,
      );

  String? validate(DateTime today) => validateMissingOrder(
        merchantId: merchantId,
        orderCode: orderCode,
        purchasedOn: purchasedOn,
        valueVnd: valueVnd,
        photoCount: photos.length,
        today: today,
      );
}

class MissingOrderForm extends Notifier<MissingOrderFormState> {
  @override
  MissingOrderFormState build() => const MissingOrderFormState();

  void setMerchant(String id) => state = state.copyWith(merchantId: id);
  void setOrderCode(String v) => state = state.copyWith(orderCode: v);
  void setDate(DateTime d) => state = state.copyWith(purchasedOn: d);
  void setValue(int v) => state = state.copyWith(valueVnd: v);

  /// Keeps at most [maxMissingOrderPhotos].
  void addPhotos(List<PickedPhoto> more) =>
      state = state.copyWith(photos: [...state.photos, ...more].take(maxMissingOrderPhotos).toList());

  void removePhoto(int i) => state = state.copyWith(photos: [...state.photos]..removeAt(i));

  /// Returns the KN code; throws the backend failure. Clears the form on success.
  Future<String?> submit(String uid, {DateTime? today}) async {
    final s = state;
    if (s.submitting) return null;
    final err = s.validate(today ?? DateTime.now());
    if (err != null) throw AppFailure('invalid_input', customMessage: err);
    state = s.copyWith(submitting: true);
    try {
      final code = await ref.read(missingOrderRepositoryProvider).submit(
            uid: uid,
            merchantId: s.merchantId!,
            orderCode: s.orderCode,
            purchasedOn: s.purchasedOn!,
            valueVnd: s.valueVnd,
            photos: s.photos,
          );
      ref.invalidate(myReportsProvider);
      state = const MissingOrderFormState();
      return code;
    } on Object {
      state = state.copyWith(submitting: false);
      rethrow;
    }
  }
}

final missingOrderFormProvider = NotifierProvider.autoDispose<MissingOrderForm, MissingOrderFormState>(MissingOrderForm.new);
