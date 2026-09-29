import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/route_paths.dart';
import '../../../../core/security/biometric_pin_vault.dart';
import '../../../../core/supabase/postgrest_error_mapper.dart';
import 'account_tile.dart';

/// Refresh after anything that changes the vault (PIN change, toggle).
final biometricStateProvider = FutureProvider.autoDispose<({bool supported, bool enabled})>((ref) async {
  final v = ref.watch(biometricPinVaultProvider);
  return (supported: await v.isSupported(), enabled: await v.isEnabled());
});

/// Toggle "Đăng nhập FaceID / Vân tay". Enabling needs the PIN verified by the
/// PIN screen (06), which pops the verified PIN back to us.
class BiometricTile extends ConsumerWidget {
  const BiometricTile({super.key, required this.hasPin});

  final bool hasPin;

  Future<void> _toggle(BuildContext context, WidgetRef ref, bool on) async {
    final vault = ref.read(biometricPinVaultProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (!on) {
        await vault.disable();
      } else if (!hasPin) {
        messenger.showSnackBar(const SnackBar(content: Text('Hãy tạo mã PIN rút tiền trước.')));
        return;
      } else {
        final pin = await context.push<String>(RoutePaths.pinVerifyReturnPin);
        if (pin == null) return;
        if (!await vault.enable(pin)) {
          messenger.showSnackBar(const SnackBar(content: Text('Chưa bật được xác thực sinh trắc học.')));
        }
      }
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(mapErrorMessage(e))));
    }
    ref.invalidate(biometricStateProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(biometricStateProvider).value;
    final supported = s?.supported ?? false;
    return AccountTile(
      icon: Icons.fingerprint,
      title: 'Đăng nhập FaceID / Vân tay',
      value: supported || s == null || s.enabled ? null : 'Không hỗ trợ',
      trailing: Switch(
        value: s?.enabled ?? false,
        onChanged: (supported || (s?.enabled ?? false)) ? (v) => _toggle(context, ref, v) : null,
      ),
    );
  }
}
