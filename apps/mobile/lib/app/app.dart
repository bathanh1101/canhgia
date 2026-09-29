import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/session_bootstrap_provider.dart';
import '../core/supabase/realtime_service.dart';
import '../features/notifications/application/push_registration.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class CanhGiaApp extends ConsumerWidget {
  const CanhGiaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(sessionBootstrapProvider); // post-login chores
    ref.watch(realtimeServiceProvider); // keeps the realtime channel alive while signed in
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'CanhGia',
      theme: buildAppTheme(),
      routerConfig: router,
      builder: (context, child) => ForegroundPushListener(
        onOpenRoute: (r) => router.push(r),
        child: child ?? const SizedBox.shrink(),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
