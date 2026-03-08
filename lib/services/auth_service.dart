import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'fcm_service.dart';

class AuthService {
  // Ganti dengan URL hosting Anda
  static const String _baseUrl = 'https://portal-smalka.com/api';

  /// Login ke server.
  /// [email] bisa email atau phone.
  /// [password] password user.
  /// [roleTab] salah satu: 'siswa', 'orang_tua', 'guru'.
  ///
  /// Mengembalikan Map hasil response dari server.
  /// Throw [AuthException] jika gagal.
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    required String roleTab,
  }) async {
    final uri = Uri.parse('$_baseUrl/login.php');

    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'password': password,
              'role_tab': roleTab,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        // Simpan data sesi ke SharedPreferences
        await _saveSession(body['data'] as Map<String, dynamic>);
        return body;
      } else {
        // Tampilkan detail debug jika ada (hapus di produksi)
        final debug = body['debug'] as String? ?? '';
        final msg = body['message'] as String? ?? 'Login gagal';
        throw AuthException(
          debug.isNotEmpty ? '$msg\n[$debug]' : msg,
          statusCode: response.statusCode,
        );
      }
    } on http.ClientException {
      throw AuthException('Tidak dapat terhubung ke server');
    } on FormatException {
      throw AuthException('Response server tidak valid');
    }
  }

  /// Simpan sesi login ke SharedPreferences.
  static Future<void> _saveSession(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', true);
    await prefs.setString('auth_token', data['token'] ?? '');
    await prefs.setInt('user_id', data['user_id'] ?? 0);
    await prefs.setString('user_name', data['name'] ?? '');
    await prefs.setString('user_email', data['email'] ?? '');
    await prefs.setString('user_phone', data['phone'] ?? '');
    await prefs.setString('user_role', data['role'] ?? '');
    await prefs.setString('user_avatar', data['avatar_url'] ?? '');

    // Simpan data tambahan sebagai JSON string
    final extraKeys = [
      'student',
      'children',
      'classes',
      'total_students',
    ];
    for (final key in extraKeys) {
      if (data.containsKey(key)) {
        await prefs.setString('user_$key', jsonEncode(data[key]));
      }
    }
  }

  /// Logout: hapus semua data sesi.
  static Future<void> logout() async {
    // Hapus FCM token dari server sebelum clear prefs
    try {
      await FcmService.instance.removeTokenFromServer();
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    // Simpan flag onboarding supaya tidak reset
    final onboarding = prefs.getBool('has_completed_initial_onboarding') ?? false;
    await prefs.clear();
    await prefs.setBool('has_completed_initial_onboarding', onboarding);
  }

  /// Cek apakah sedang login.
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_logged_in') ?? false;
  }

  /// Ambil role user yang sedang login.
  static Future<String> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_role') ?? '';
  }

  /// Ambil nama user yang sedang login.
  static Future<String> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_name') ?? '';
  }

  /// Ambil token autentikasi.
  static Future<String> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token') ?? '';
  }
}

/// Custom exception untuk error autentikasi.
class AuthException implements Exception {
  final String message;
  final int? statusCode;

  AuthException(this.message, {this.statusCode});

  @override
  String toString() => message;
}
