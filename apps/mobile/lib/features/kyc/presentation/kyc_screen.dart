import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/profile_provider.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/widgets/async_value_view.dart';
import '../application/kyc_providers.dart';
import 'widgets/kyc_bank_step.dart';
import 'widgets/kyc_identity_step.dart';
import 'widgets/kyc_pin_step.dart';
import 'widgets/kyc_stepper.dart';

/// Screen 12 - 3-step "Tài khoản nhận tiền". Opens at [initialStep] but never past
/// the first step still incomplete (kyc status / bank accounts / has_pin).
class KycScreen extends ConsumerStatefulWidget {
  const KycScreen({super.key, this.initialStep});

  final int? initialStep;

  @override
  ConsumerState<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends ConsumerState<KycScreen> {
  int? _override;

  @override
  Widget build(BuildContext context) {
    final resume = ref.watch(kycResumeStepProvider);
    final profile = ref.watch(kycProfileProvider);
    return Scaffold(
      appBar: const AppTopBar(title: 'Tài khoản nhận tiền'),
      body: AsyncValueView(
        value: resume,
        onRetry: () {
          ref.invalidate(kycProfileProvider);
          ref.invalidate(kycResumeStepProvider);
        },
        data: (r) {
          final step = (_override ?? (widget.initialStep ?? r)).clamp(1, r);
          final p = profile.value;
          return ListView(padding: const EdgeInsets.all(16), children: [
            KycStepper(current: step),
            const SizedBox(height: 8),
            switch (step) {
              1 => KycIdentityStep(profile: p),
              2 when p != null => KycBankStep(profile: p, onDone: () => setState(() => _override = 3)),
              _ => KycPinStep(hasPin: ref.watch(profileProvider).value?.hasPin ?? false),
            },
          ]);
        },
      ),
    );
  }
}
