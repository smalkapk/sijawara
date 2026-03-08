import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

/// Service untuk komunikasi dengan API siswa profile update.
class SiswaProfileService {
  static const String _baseUrl = 'https://portal-smalka.com/api';

  // ═══════════════════════════════════════
  // GET: Ambil data profil siswa saat ini
  // ═══════════════════════════════════════
  static Future<SiswaProfileData> getProfile() async {
    final token = await AuthService.getToken();
    final uri = Uri.parse('$_baseUrl/siswa_update_profile.php');

    try {
      final response = await http.get(uri, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      }).timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        return SiswaProfileData.fromJson(body['data']);
      } else {
        throw SiswaProfileServiceException(
          body['message'] ?? 'Gagal mengambil data profil',
        );
      }
    } on TimeoutException {
      throw SiswaProfileServiceException('Koneksi timeout, coba lagi');
    } on http.ClientException {
      throw SiswaProfileServiceException('Tidak dapat terhubung ke server');
    } on FormatException {
      throw SiswaProfileServiceException('Response server tidak valid');
    } catch (e) {
      if (e is SiswaProfileServiceException) rethrow;
      throw SiswaProfileServiceException('Terjadi kesalahan: $e');
    }
  }

  // ═══════════════════════════════════════
  // POST: Update profil siswa (nama, email, phone)
  // ═══════════════════════════════════════
  static Future<SiswaProfileData> updateProfile({
    required String name,
    String? email,
    String? phone,
  }) async {
    final token = await AuthService.getToken();
    final uri = Uri.parse('$_baseUrl/siswa_update_profile.php');

    try {
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'name': name,
          'email': email ?? '',
          'phone': phone ?? '',
        }),
      ).timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        final data = SiswaProfileData.fromJson(body['data']);
        // Update SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_name', data.name);
        await prefs.setString('user_email', data.email);
        await prefs.setString('user_phone', data.phone);
        return data;
      } else {
        throw SiswaProfileServiceException(
          body['message'] ?? 'Gagal memperbarui profil',
        );
      }
    } on TimeoutException {
      throw SiswaProfileServiceException('Koneksi timeout, coba lagi');
    } on http.ClientException {
      throw SiswaProfileServiceException('Tidak dapat terhubung ke server');
    } on FormatException {
      throw SiswaProfileServiceException('Response server tidak valid');
    } catch (e) {
      if (e is SiswaProfileServiceException) rethrow;
      throw SiswaProfileServiceException('Terjadi kesalahan: $e');
    }
  }

  // ═══════════════════════════════════════
  // POST: Upload avatar siswa (file)
  // ═══════════════════════════════════════
  static Future<String> uploadAvatar(File imageFile) async {
    final token = await AuthService.getToken();
    final uri = Uri.parse('$_baseUrl/siswa_update_profile.php');

    try {
      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(
        await http.MultipartFile.fromPath('avatar', imageFile.path),
      );

      final streamResponse =
          await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamResponse);
      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        final url = body['data']['avatar_url'] ?? '';
        // Update SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_avatar', url);
        return url;
      } else {
        throw SiswaProfileServiceException(
          body['message'] ?? 'Gagal mengupload foto',
        );
      }
    } on TimeoutException {
      throw SiswaProfileServiceException('Koneksi timeout, coba lagi');
    } on http.ClientException {
      throw SiswaProfileServiceException('Tidak dapat terhubung ke server');
    } catch (e) {
      if (e is SiswaProfileServiceException) rethrow;
      throw SiswaProfileServiceException('Terjadi kesalahan: $e');
    }
  }

  // ═══════════════════════════════════════
  // POST: Set avatar URL langsung (DiceBear)
  // ═══════════════════════════════════════
  static Future<String> setAvatarUrl(String avatarUrl) async {
    final token = await AuthService.getToken();
    final uri = Uri.parse('$_baseUrl/siswa_update_profile.php');

    try {
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'avatar_url': avatarUrl}),
      ).timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        final url = body['data']['avatar_url'] ?? avatarUrl;
        // Update SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_avatar', url);
        return url;
      } else {
        throw SiswaProfileServiceException(
          body['message'] ?? 'Gagal memperbarui avatar',
        );
      }
    } on TimeoutException {
      throw SiswaProfileServiceException('Koneksi timeout, coba lagi');
    } on http.ClientException {
      throw SiswaProfileServiceException('Tidak dapat terhubung ke server');
    } catch (e) {
      if (e is SiswaProfileServiceException) rethrow;
      throw SiswaProfileServiceException('Terjadi kesalahan: $e');
    }
  }
}

// ═══════════════════════════════════════
// DATA MODEL
// ═══════════════════════════════════════

class SiswaProfileData {
  final int userId;
  final String name;
  final String email;
  final String phone;
  final String avatarUrl;
  final String className;

  SiswaProfileData({
    required this.userId,
    required this.name,
    required this.email,
    required this.phone,
    required this.avatarUrl,
    required this.className,
  });

  factory SiswaProfileData.fromJson(Map<String, dynamic> json) {
    return SiswaProfileData(
      userId: json['user_id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String? ?? '',
      className: json['class_name'] as String? ?? '-',
    );
  }
}

/// Custom exception for siswa profile service errors.
class SiswaProfileServiceException implements Exception {
  final String message;

  SiswaProfileServiceException(this.message);

  @override
  String toString() => message;
}
