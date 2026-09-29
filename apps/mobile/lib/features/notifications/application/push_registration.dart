import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/env.dart';
import '../data/app_notification.dart';

/// A push received while the app is in the foreground.
class ForegroundPush {
  const ForegroundPush({required this.title, this.body, this.route});
  final String title;
  final String? body;

  /// Already validated with [safeRoute].
  final String? route;
}

ForegroundPush? pushFromMessage(RemoteMessage m) {
  String? str(Object? v) => v is String ? v : null; // payload values are untrusted: never cast
  final title = m.notification?.title ?? str(m.data['title']);
  if (title == null || title.trim().isEmpty) return null;
  return ForegroundPush(title: title, body: m.notification?.body ?? str(m.data['body']), route: safeRoute(m.data['route']));
}

/// Token registration lives in core `PushTokenService`; this only surfaces foreground messages.
/// Empty unless FCM is enabled (Firebase initialised in main.dart).
final foregroundPushProvider = StreamProvider<ForegroundPush>((ref) {
  if (!Env.fcmEnabled) return const Stream.empty();
  return FirebaseMessaging.onMessage.map(pushFromMessage).where((p) => p != null).cast<ForegroundPush>();
});

/// Wrap the app (e.g. in `MaterialApp.builder`) to show a snackbar for foreground pushes.
/// [onOpenRoute] navigates (e.g. `(r) => ref.read(routerProvider).push(r)`); without it no "Xem" action is shown.
class ForegroundPushListener extends ConsumerWidget {
  const ForegroundPushListener({super.key, required this.child, this.onOpenRoute});

  final Widget child;
  final void Function(String route)? onOpenRoute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(foregroundPushProvider, (_, next) {
      final push = next.value;
      if (push == null) return;
      final route = push.route;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(push.body == null ? push.title : '${push.title}\n${push.body}'),
        action: route == null || onOpenRoute == null ? null : SnackBarAction(label: 'Xem', onPressed: () => onOpenRoute!(route)),
      ));
    });
    return child;
  }
}
