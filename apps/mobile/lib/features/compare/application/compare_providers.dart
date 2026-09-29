import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../data/compare_repository.dart';

final compareRepositoryProvider = Provider<CompareRepository>((ref) => CompareRepository(ref.watch(supabaseProvider)));

final compareProvider = FutureProvider.family<List<CompareOffer>, String>((ref, groupId) async {
  final id = int.tryParse(groupId);
  return id == null ? const [] : ref.watch(compareRepositoryProvider).compare(id);
});
