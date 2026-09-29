import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Single access point to the initialised client; override in tests.
final supabaseProvider = Provider<SupabaseClient>((ref) => Supabase.instance.client);
