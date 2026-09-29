import 'package:http/http.dart' as http;
import 'dart:convert';

class MailpitClient {
  static const String baseUrl = 'http://10.0.2.2:55324'; // Android emulator localhost

  /// Fetch OTP code from latest email to recipient
  static Future<String> getOtpCode(String recipient) async {
    try {
      // Mailpit API: GET /api/messages?search=to:<recipient>
      final response = await http.get(
        Uri.parse('$baseUrl/api/messages?search=to:$recipient'),
      );

      if (response.statusCode != 200) {
        throw Exception('Mailpit error: ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as Map;
      final messages = (data['messages'] as List?)?.cast<Map>();
      if (messages == null || messages.isEmpty) {
        throw Exception('No emails found for $recipient');
      }

      final latestEmail = messages.first;
      final body = latestEmail['text'] as String? ?? latestEmail['html'] ?? '';

      // Extract OTP (6-digit code)
      final regex = RegExp(r'\b\d{6}\b');
      final match = regex.firstMatch(body);
      if (match == null) {
        throw Exception('No OTP code found in email body');
      }

      return match.group(0)!;
    } catch (e) {
      rethrow;
    }
  }

  /// Clear all emails
  static Future<void> clearEmails() async {
    await http.delete(Uri.parse('$baseUrl/api/messages'));
  }
}
