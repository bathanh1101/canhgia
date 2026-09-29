import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/device/device_identity_service.dart';
import '../../../core/supabase/postgrest_error_mapper.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../home/data/link_models.dart';
import '../../home/data/link_repository.dart';

final linkRepositoryProvider = Provider<LinkRepository>((ref) => LinkRepository(ref.watch(supabaseProvider)));

/// Opens a URL outside the app (Shopee/Lazada universal links). Overridden in tests.
final externalLauncherProvider = Provider<Future<bool> Function(Uri)>(
  (ref) => (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

final shareTextProvider = Provider<Future<void> Function(String)>(
  (ref) => (text) async {
    await SharePlus.instance.share(ShareParams(text: text));
  },
);

final clipboardWriterProvider = Provider<Future<void> Function(String)>(
  (ref) => (text) => Clipboard.setData(ClipboardData(text: text)),
);

/// Only http(s) leaves the app; anything else from the backend is refused.
Uri? safeExternalUri(String raw) {
  final u = Uri.tryParse(raw.trim());
  return u != null && (u.scheme == 'https' || u.scheme == 'http') && u.host.isNotEmpty ? u : null;
}

/// Time left to buy after creating the link (never negative).
Duration activationRemaining(CreatedLink link, DateTime now) {
  final left = link.createdAt.add(link.activationWindow).difference(now);
  return left.isNegative ? Duration.zero : left;
}

/// "23:59:07" / "2 ngày 03:10:00".
String formatCountdown(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  final hms = '${two(d.inDays > 0 ? d.inHours % 24 : d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
  return d.inDays > 0 ? '${d.inDays} ngày $hms' : hms;
}

/// Holds the in-flight/last create-link result. [create] returns null on failure and leaves the error in state.
class CreateLinkController extends AsyncNotifier<CreatedLink?> {
  @override
  CreatedLink? build() => null;

  Future<CreatedLink?> create({
    required String merchantId,
    String? url,
    String? name,
    int? priceVnd,
    String? image,
  }) async {
    if (state.isLoading) return null;
    state = const AsyncLoading();
    try {
      final link = await ref.read(linkRepositoryProvider).create(
            merchantId: merchantId,
            url: url,
            deviceId: ref.read(deviceIdProvider),
          );
      final withProduct = link.withProduct(name: name, priceVnd: priceVnd, image: image);
      state = AsyncData(withProduct);
      return withProduct;
    } on Object catch (e, st) {
      state = AsyncError(AppFailure.from(e), st);
      return null;
    }
  }
}

final createLinkControllerProvider = AsyncNotifierProvider<CreateLinkController, CreatedLink?>(CreateLinkController.new);

/// `hold_days` per merchant (get_merchant_rates; core Merchant model does not carry it).
final merchantHoldDaysProvider = FutureProvider<Map<String, int>>((ref) async {
  final rows = await ref.watch(supabaseProvider).rpc('get_merchant_rates') as List;
  return {
    for (final r in rows)
      if ((r as Map)['hold_days'] is num) r['merchant_id'] as String: (r['hold_days'] as num).toInt(),
  };
});
