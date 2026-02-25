import 'dart:convert';
import 'package:http/http.dart' as http;

class LlmMessage {
  final String role; // 'user', 'assistant', or 'system'
  final String content;

  LlmMessage({required this.role, required this.content});

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

class AlkaAiService {
  // Gunakan URL API hosting yang sama dengan login, sesuaikan path jika perlu
  static const String _baseUrl = 'https://portal-smalka.com/api';

  static Future<String> sendMessage(List<LlmMessage> messages) async {
    final uri = Uri.parse('$_baseUrl/alka_ai.php');

    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'messages': messages.map((m) => m.toJson()).toList(),
            }),
          )
          .timeout(
            const Duration(seconds: 45),
          ); // Waktu tunggu sedikit lama untuk AI

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['choices'] != null && body['choices'].isNotEmpty) {
          return body['choices'][0]['message']['content'];
        } else {
          throw Exception('Format response tidak sesuai dari AI');
        }
      } else {
        final body = jsonDecode(response.body);
        throw Exception(body['error'] ?? 'Terjadi kesalahan dari server');
      }
    } catch (e) {
      throw Exception('Gagal menghubungi ALKA AI: $e');
    }
  }
}
