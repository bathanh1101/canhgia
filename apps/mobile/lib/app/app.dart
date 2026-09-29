import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/session_bootstrap_provider.dart';
import '../core/supabase/realtime_service.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class CanhGiaApp extends ConsumerWidget {
  const CanhGiaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(sessionBootstrapProvider); // post-login chores
    ref.watch(realtimeServiceProvider); // keeps the realtime channel alive while signed in
    return MaterialApp.router(
      title: 'CanhGia',
      theme: buildAppTheme(),
      routerConfig: ref.watch(routerProvider),
      debugShowCheckedModeBanner: false,
    );
  }
}
