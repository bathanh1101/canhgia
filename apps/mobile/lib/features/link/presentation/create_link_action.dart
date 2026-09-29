import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/route_paths.dart';
import '../../../core/supabase/postgrest_error_mapper.dart';
import '../application/link_providers.dart';

/// Shared "tạo link hoàn tiền" flow (home card, vouchers, compare): create-link then open the link screen.
/// Failures (rate_limited, account_locked, merchant_unavailable, unsupported_url...) become a snackbar.
Future<void> runCreateLink(
  BuildContext context,
  WidgetRef ref, {
  required String merchantId,
  String? url,
  String? name,
  int? priceVnd,
  String? image,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);
  final link = await ref
      .read(createLinkControllerProvider.notifier)
      .create(merchantId: merchantId, url: url, name: name, priceVnd: priceVnd, image: image);
  if (link == null) {
    final err = ref.read(createLinkControllerProvider).error;
    if (err != null) messenger.showSnackBar(SnackBar(content: Text(mapErrorMessage(err))));
    return;
  }
  router.push(RoutePaths.linkFor(link.clickId), extra: link);
}
