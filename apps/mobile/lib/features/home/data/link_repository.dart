import 'package:supabase_flutter/supabase_flutter.dart';

import 'link_models.dart';

/// resolve-url / create-link Edge calls + record_link_share. Errors surface as
/// FunctionException / PostgrestException; callers map them with `mapErrorMessage`.
class LinkRepository {
  LinkRepository(this._db);
  final SupabaseClient _db;

  Future<ResolvedUrl> resolve(String url) async {
    final res = await _db.functions.invoke('resolve-url', body: {'url': url.trim()});
    return ResolvedUrl.fromJson(res.data);
  }

  /// [url] null for travel merchants (campaign default page).
  Future<CreatedLink> create({required String merchantId, required String deviceId, String? url}) async {
    final res = await _db.functions.invoke('create-link', body: {
      'merchant_id': merchantId,
      'source': 'app',
      'device_id': deviceId,
      if (url != null && url.isNotEmpty) 'url': url,
    });
    return CreatedLink.fromJson(res.data);
  }

  Future<void> recordShare(String clickId) async {
    final id = int.tryParse(clickId);
    if (id == null) return;
    await _db.rpc('record_link_share', params: {'p_click_id': id});
  }
}
