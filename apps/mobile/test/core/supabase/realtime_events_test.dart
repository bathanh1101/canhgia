import 'dart:async';

import 'package:canhgia_mobile/core/supabase/realtime_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('repeated identical events are all delivered to ref.listen consumers', () async {
    final ctl = StreamController<RealtimeEvent>.broadcast();
    addTearDown(ctl.close);
    final c = ProviderContainer(overrides: [realtimeEventsProvider.overrideWith((_) => ctl.stream)]);
    addTearDown(c.dispose);
    final seen = <String>[];
    c.listen(realtimeEventsProvider, (_, e) => seen.add(e.value!.kind));
    for (var i = 0; i < 3; i++) {
      ctl.add(RealtimeEvent('orders'));
      await Future<void>.delayed(Duration.zero);
    }
    ctl.add(RealtimeEvent(RealtimeService.resync));
    await Future<void>.delayed(Duration.zero);
    ctl.add(RealtimeEvent(RealtimeService.resync));
    await Future<void>.delayed(Duration.zero);
    expect(seen, ['orders', 'orders', 'orders', 'resync', 'resync']);
  });
}
