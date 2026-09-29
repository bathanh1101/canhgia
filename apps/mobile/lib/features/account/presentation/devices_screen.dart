import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_text_styles.dart';
import '../../../core/utils/format_date.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../application/account_providers.dart';

class DevicesScreen extends ConsumerWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: const AppTopBar(title: 'Thiết bị đăng nhập'),
        body: AsyncValueView(
          value: ref.watch(userDevicesProvider),
          onRetry: () => ref.invalidate(userDevicesProvider),
          data: (list) => list.isEmpty
              ? const EmptyState(message: 'Chưa có thiết bị nào.')
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => AppCard(
                    child: Row(children: [
                      Icon(list[i].platform == 'ios' ? Icons.phone_iphone : Icons.phone_android),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(list[i].model ?? (list[i].platform == 'ios' ? 'iPhone' : 'Android'), style: AppText.title),
                          Text('Hoạt động lần cuối ${formatDateTime(list[i].lastSeenAt)}', style: AppText.caption),
                        ]),
                      ),
                    ]),
                  ),
                ),
        ),
      );
}
