import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/route_paths.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/providers/unread_notifications_provider.dart';
import '../../../core/supabase/postgrest_error_mapper.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/filter_chip_bar.dart';
import '../application/notifications_providers.dart';
import '../data/app_notification.dart';
import 'widgets/notification_tile.dart';

/// Screen 10 - grouped notification list; tap opens `data.route`.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key, this.now});

  final DateTime? now;

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  var _tab = NotificationTab.all;

  Future<void> _markRead(List<int>? ids) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(notificationsRepositoryProvider).markRead(ids);
      if (!mounted) return;
      ref
        ..invalidate(notificationsProvider)
        ..invalidate(unreadNotificationsProvider);
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(mapErrorMessage(e))));
    }
  }

  Future<void> _open(AppNotification n) async {
    final route = n.route;
    if (!n.isRead) await _markRead([n.id]);
    if (route != null && mounted) context.push(route);
  }

  @override
  Widget build(BuildContext context) {
    final now = widget.now ?? DateTime.now();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo'),
        actions: [
          TextButton(onPressed: () => _markRead(null), child: const Text('Đọc tất cả')),
          IconButton(
            tooltip: 'Cài đặt thông báo',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(RoutePaths.accountNotificationSettings),
          ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: FilterChipBar<NotificationTab>(
            options: {for (final t in NotificationTab.values) t: t.label},
            selected: _tab,
            onSelected: (t) => setState(() => _tab = t),
          ),
        ),
        Expanded(
          child: AsyncValueView(
            value: ref.watch(notificationsProvider(_tab)),
            onRetry: () => ref.invalidate(notificationsProvider(_tab)),
            data: (list) => list.isEmpty
                ? const EmptyState(message: 'Chưa có thông báo nào.', icon: Icons.notifications_none)
                : ListView(padding: const EdgeInsets.all(16), children: [
                    for (final g in groupByDay(list, now)) ...[
                      Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(g.label, style: AppText.label)),
                      AppCard(
                        padding: EdgeInsets.zero,
                        child: Column(children: [
                          for (final n in g.items) NotificationTile(item: n, now: now, onTap: () => _open(n)),
                        ]),
                      ),
                    ],
                  ]),
          ),
        ),
      ]),
    );
  }
}
