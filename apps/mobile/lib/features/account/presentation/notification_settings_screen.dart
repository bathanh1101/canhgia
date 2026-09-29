import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/profile_provider.dart';
import '../../../core/supabase/postgrest_error_mapper.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/widgets/async_value_view.dart';
import '../application/account_providers.dart';

const _labels = {
  'order': 'Đơn hàng',
  'wallet': 'Ví tiền',
  'promo': 'Khuyến mãi',
  'referral': 'Mời bạn',
};

/// Writes `profiles.notification_prefs` (read server-side by send-push).
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  Future<void> _set(BuildContext context, WidgetRef ref, Map<String, bool> prefs, String key, bool on) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(accountRepositoryProvider).updateProfile(notificationPrefs: {...prefs, key: on});
      ref.invalidate(profileProvider);
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(mapErrorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: const AppTopBar(title: 'Cài đặt thông báo'),
        body: AsyncValueView(
          value: ref.watch(profileProvider),
          onRetry: () => ref.invalidate(profileProvider),
          data: (p) {
            final prefs = {for (final k in _labels.keys) k: p?.notificationPrefs[k] ?? true};
            return ListView(children: [
              for (final e in _labels.entries)
                SwitchListTile(
                  title: Text('Thông báo ${e.value.toLowerCase()}'),
                  value: prefs[e.key]!,
                  onChanged: (v) => _set(context, ref, prefs, e.key, v),
                ),
            ]);
          },
        ),
      );
}
