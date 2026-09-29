import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/postgrest_error_mapper.dart';
import '../../application/voucher_providers.dart';

/// "Lưu" / "Đã lưu" toggle backed by saved_vouchers (optimistic, error -> snackbar).
class SaveVoucherButton extends ConsumerWidget {
  const SaveVoucherButton({super.key, required this.voucherId, this.savedLabel = 'Đã lưu', this.saveLabel = 'Lưu'});

  final int voucherId;
  final String saveLabel;
  final String savedLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedVoucherIdsProvider).value?.contains(voucherId) ?? false;
    return TextButton(
      onPressed: () async {
        final messenger = ScaffoldMessenger.of(context);
        try {
          await ref.read(savedVoucherIdsProvider.notifier).toggle(voucherId);
        } on Object catch (e) {
          messenger.showSnackBar(SnackBar(content: Text(mapErrorMessage(e))));
        }
      },
      child: Text(saved ? savedLabel : saveLabel),
    );
  }
}
