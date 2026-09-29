import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/merchant.dart';
import '../supabase/supabase_providers.dart';

/// `get_merchant_rates()` - SSOT for merchant domains (clipboard gate), badge letters, max rates.
final merchantsProvider = FutureProvider<List<Merchant>>((ref) async {
  final rows = await ref.watch(supabaseProvider).rpc('get_merchant_rates') as List;
  return [for (final r in rows) Merchant.fromJson(r as Map<String, dynamic>)];
});

/// Highest active cashback rate (bps) via `get_public_settings().max_rate_bps`; 0 if unknown.
final maxRateBpsProvider = FutureProvider<int>((ref) async {
  final s = await ref.watch(supabaseProvider).rpc('get_public_settings') as Map<String, dynamic>;
  return (s['max_rate_bps'] as num?)?.toInt() ?? 0;
});
