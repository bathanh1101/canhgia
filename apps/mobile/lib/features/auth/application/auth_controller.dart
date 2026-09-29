import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/security/biometric_pin_vault.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../data/auth_repository.dart';

final authRepositoryProvider =
    Provider<AuthRepository>((ref) => AuthRepository(ref.watch(supabaseProvider).auth));

/// Drives login buttons. State: loading while a call is in flight, error to show
/// via `mapErrorMessage(state.error)`. Success is observed through the session
/// (router redirects to /home), not through this state.
class AuthController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<void> signInWithGoogle() => _run(_repo.signInWithGoogle);

  Future<void> sendEmailOtp(String email, {String? captchaToken}) =>
      _run(() => _repo.sendEmailOtp(email, captchaToken: captchaToken));

  Future<void> verifyEmailOtp(String email, String code) => _run(() => _repo.verifyEmailOtp(email, code));

  Future<void> signOut() => _run(() async {
        await ref.read(biometricPinVaultProvider).disable();
        await _repo.signOut();
        return null;
      });

  Future<void> _run(Future<Object?> Function() action) async {
    if (state.isLoading) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(action);
  }
}

final authControllerProvider = NotifierProvider<AuthController, AsyncValue<void>>(AuthController.new);
