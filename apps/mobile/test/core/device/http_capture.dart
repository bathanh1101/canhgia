// ignore_for_file: depend_on_referenced_packages
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// SupabaseClient whose HTTP layer records requests and answers with [body].
({SupabaseClient client, List<http.Request> requests}) capturingClient({String body = '[]'}) {
  final requests = <http.Request>[];
  final client = SupabaseClient(
    'http://localhost',
    'anon',
    httpClient: MockClient((r) async {
      requests.add(r);
      return http.Response(body, 200, request: r, headers: {'content-range': '*/0', 'content-type': 'application/json'});
    }),
  );
  return (client: client, requests: requests);
}
