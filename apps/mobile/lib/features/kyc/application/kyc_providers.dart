import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_session_provider.dart';
import '../../../core/providers/profile_provider.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../withdraw/application/withdraw_providers.dart';
import '../data/kyc_repository.dart';
import '../data/photo.dart';
import 'kyc_logic.dart';

final photoPickerProvider = Provider<PhotoPicker>((ref) => ImagePickerPhotoPicker());

final photoUploaderProvider = Provider<PhotoUploader>((ref) => PhotoUploader(ref.watch(supabaseProvider)));

final kycRepositoryProvider =
    Provider<KycRepository>((ref) => KycRepository(ref.watch(supabaseProvider), ref.watch(photoUploaderProvider)));

final kycProfileProvider = FutureProvider.autoDispose<KycProfile?>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  return uid == null ? null : ref.watch(kycRepositoryProvider).profile(uid);
});

/// Where the stepper resumes: profile.status, bank account count, `profiles.has_pin`.
final kycResumeStepProvider = FutureProvider.autoDispose<int>((ref) async {
  final profile = await ref.watch(kycProfileProvider.future);
  final banks = await ref.watch(bankAccountsProvider.future);
  final me = await ref.watch(profileProvider.future);
  return kycResumeStep(profile: profile, bankAccounts: banks.length, hasPin: me?.hasPin ?? false);
});
