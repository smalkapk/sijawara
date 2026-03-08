import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

/// Service untuk komunikasi dengan API guru profile.
class GuruProfileService {
  static const String _baseUrl = 'https://portal-smalka.com/api';

  // ═══════════════════════════════════════
  // GET: Ambil data profil guru (lengkap dgn positions)
  // ═══════════════════════════════════════
  static Future<GuruProfileData> getProfile() async {
    final token = await AuthService.getToken();
    final uri = Uri.parse('$_baseUrl/guru_profile.php');

    try {
      final response = await http.get(uri, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      }).timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        return GuruProfileData.fromJson(body['data']);
      } else {
        throw GuruProfileServiceException(
          body['message'] ?? 'Gagal mengambil data profil guru',
        );
      }
    } on TimeoutException {
      throw GuruProfileServiceException('Koneksi timeout, coba lagi');
    } on http.ClientException {
      throw GuruProfileServiceException('Tidak dapat terhubung ke server');
    } on FormatException {
      throw GuruProfileServiceException('Response server tidak valid');
    } catch (e) {
      if (e is GuruProfileServiceException) rethrow;
      throw GuruProfileServiceException('Terjadi kesalahan: $e');
    }
  }

  // ═══════════════════════════════════════
  // POST: Update profil guru (nama, email, phone)
  // ═══════════════════════════════════════
  static Future<void> updateProfile({
    required String name,
    String? email,
    String? phone,
  }) async {
    final token = await AuthService.getToken();
    final uri = Uri.parse('$_baseUrl/guru_update_profile.php');

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
        return;
      } else {
        throw GuruProfileServiceException(
          body['message'] ?? 'Gagal memperbarui profil',
        );
      }
    } on TimeoutException {
      throw GuruProfileServiceException('Koneksi timeout, coba lagi');
    } on http.ClientException {
      throw GuruProfileServiceException('Tidak dapat terhubung ke server');
    } on FormatException {
      throw GuruProfileServiceException('Response server tidak valid');
    } catch (e) {
      if (e is GuruProfileServiceException) rethrow;
      throw GuruProfileServiceException('Terjadi kesalahan: $e');
    }
  }

  // ═══════════════════════════════════════
  // POST: Upload avatar guru (file)
  // ═══════════════════════════════════════
  static Future<String> uploadAvatar(File imageFile) async {
    final token = await AuthService.getToken();
    final uri = Uri.parse('$_baseUrl/guru_update_profile.php');

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
        return body['data']['avatar_url'] ?? '';
      } else {
        throw GuruProfileServiceException(
          body['message'] ?? 'Gagal mengupload foto',
        );
      }
    } on TimeoutException {
      throw GuruProfileServiceException('Koneksi timeout, coba lagi');
    } on http.ClientException {
      throw GuruProfileServiceException('Tidak dapat terhubung ke server');
    } catch (e) {
      if (e is GuruProfileServiceException) rethrow;
      throw GuruProfileServiceException('Terjadi kesalahan: $e');
    }
  }

  // ═══════════════════════════════════════
  // POST: Set avatar URL langsung (DiceBear)
  // ═══════════════════════════════════════
  static Future<String> setAvatarUrl(String avatarUrl) async {
    final token = await AuthService.getToken();
    final uri = Uri.parse('$_baseUrl/guru_update_profile.php');

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
        return body['data']['avatar_url'] ?? avatarUrl;
      } else {
        throw GuruProfileServiceException(
          body['message'] ?? 'Gagal memperbarui avatar',
        );
      }
    } on TimeoutException {
      throw GuruProfileServiceException('Koneksi timeout, coba lagi');
    } on http.ClientException {
      throw GuruProfileServiceException('Tidak dapat terhubung ke server');
    } catch (e) {
      if (e is GuruProfileServiceException) rethrow;
      throw GuruProfileServiceException('Terjadi kesalahan: $e');
    }
  }

  // ═══════════════════════════════════════
  // GET: Ambil data profil ringkas (nama, avatar, role)
  // ═══════════════════════════════════════
  static Future<GuruBasicProfile> getBasicProfile() async {
    final token = await AuthService.getToken();
    final uri = Uri.parse('$_baseUrl/guru_update_profile.php');

    try {
      final response = await http.get(uri, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      }).timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        return GuruBasicProfile.fromJson(body['data']);
      } else {
        throw GuruProfileServiceException(
          body['message'] ?? 'Gagal mengambil data profil guru',
        );
      }
    } on TimeoutException {
      throw GuruProfileServiceException('Koneksi timeout, coba lagi');
    } on http.ClientException {
      throw GuruProfileServiceException('Tidak dapat terhubung ke server');
    } on FormatException {
      throw GuruProfileServiceException('Response server tidak valid');
    } catch (e) {
      if (e is GuruProfileServiceException) rethrow;
      throw GuruProfileServiceException('Terjadi kesalahan: $e');
    }
  }
}

// ═══════════════════════════════════════
// DATA MODELS
// ═══════════════════════════════════════

class GuruProfileData {
  final GuruProfile profile;
  final List<GuruPosition> positions;

  GuruProfileData({
    required this.profile,
    required this.positions,
  });

  factory GuruProfileData.fromJson(Map<String, dynamic> json) {
    final profileJson = json['profile'] as Map<String, dynamic>;
    final positionsList = (json['positions'] as List)
        .map((e) => GuruPosition.fromJson(e as Map<String, dynamic>))
        .toList();

    return GuruProfileData(
      profile: GuruProfile.fromJson(profileJson),
      positions: positionsList,
    );
  }
}

class GuruProfile {
  final int userId;
  final String name;
  final String? email;
  final String? phone;
  final String? avatarUrl;
  final String role;
  final String roleLabel;
  final String? createdAt;

  GuruProfile({
    required this.userId,
    required this.name,
    this.email,
    this.phone,
    this.avatarUrl,
    required this.role,
    required this.roleLabel,
    this.createdAt,
  });

  factory GuruProfile.fromJson(Map<String, dynamic> json) {
    return GuruProfile(
      userId: json['user_id'] as int,
      name: json['name'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      role: json['role'] as String? ?? 'guru',
      roleLabel: json['role_label'] as String? ?? 'Guru',
      createdAt: json['created_at'] as String?,
    );
  }
}

class GuruPosition {
  final String type;
  final String title;
  final String subtitle;
  final String icon;
  final String color;

  GuruPosition({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  factory GuruPosition.fromJson(Map<String, dynamic> json) {
    return GuruPosition(
      type: json['type'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      icon: json['icon'] as String? ?? 'work',
      color: json['color'] as String? ?? '#059669',
    );
  }
}

/// Custom exception for guru profile service errors.
class GuruProfileServiceException implements Exception {
  final String message;

  GuruProfileServiceException(this.message);

  @override
  String toString() => message;
}

/// Lightweight profile model from guru_update_profile.php GET
class GuruBasicProfile {
  final int userId;
  final String name;
  final String email;
  final String phone;
  final String avatarUrl;
  final String role;

  GuruBasicProfile({
    required this.userId,
    required this.name,
    required this.email,
    required this.phone,
    required this.avatarUrl,
    required this.role,
  });

  String get roleLabel {
    if (role == 'guru_tahfidz') return 'Guru Tahfidz';
    if (role == 'guru_kelas') return 'Guru Kelas';
    return 'Guru';
  }

  factory GuruBasicProfile.fromJson(Map<String, dynamic> json) {
    return GuruBasicProfile(
      userId: json['user_id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String? ?? '',
      role: json['role'] as String? ?? 'guru',
    );
  }
}
