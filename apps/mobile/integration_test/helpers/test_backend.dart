import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class TestBackend {
  static const String baseUrl = 'http://10.0.2.2:55321'; // Android emulator localhost
  static const String serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9';
  static const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9';

  static Future<Map<String, dynamic>> callFunction(
    String functionName,
    Map<String, dynamic> body, {
    String? authToken,
  }) async {
    final headers = {
      'Content-Type': 'application/json',
      'apikey': anonKey,
      if (authToken != null) 'Authorization': 'Bearer $authToken',
    };

    final response = await http.post(
      Uri.parse('$baseUrl/functions/v1/$functionName'),
      headers: headers,
      body: jsonEncode(body),
    );

    if (response.statusCode >= 400) {
      throw Exception('Function error: ${response.statusCode} - ${response.body}');
    }

    return jsonDecode(response.body);
  }

  static Future<void> resetTestDatabase() async {
    try {
      await Process.run(
        'psql',
        ['-h', '127.0.0.1', '-p', '55322', '-U', 'postgres', '-d', 'postgres', '-c', 'SELECT 1;'],
      );
    } catch (e) {
      throw Exception('DB reset failed: $e');
    }
  }
}
