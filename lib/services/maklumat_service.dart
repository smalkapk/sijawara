import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

/// Peta icon yang tersedia untuk maklumat.
/// Key = nama string yang disimpan di DB, Value = (IconData, Color).
const Map<String, (IconData, Color)> maklumatIconMap = {
  'campaign':       (Icons.campaign_rounded,           Color(0xFFEF4444)),
  'school':         (Icons.school_rounded,             Color(0xFF3B82F6)),
  'event':          (Icons.event_rounded,              Color(0xFF1B8A4A)),
  'info':           (Icons.info_rounded,               Color(0xFF6366F1)),
  'warning':        (Icons.warning_rounded,            Color(0xFFF59E0B)),
  'celebration':    (Icons.celebration_rounded,         Color(0xFFEC4899)),
  'menu_book':      (Icons.menu_book_rounded,          Color(0xFF8B5CF6)),
  'emoji_events':   (Icons.emoji_events_rounded,       Color(0xFFEAB308)),
  'mosque':         (Icons.mosque_rounded,             Color(0xFF14B8A6)),
  'groups':         (Icons.groups_rounded,             Color(0xFF0EA5E9)),
  'health':         (Icons.health_and_safety_rounded,  Color(0xFF10B981)),
  'payments':       (Icons.payments_rounded,           Color(0xFF64748B)),
  'directions_bus': (Icons.directions_bus_rounded,     Color(0xFFF97316)),
  'restaurant':     (Icons.restaurant_rounded,         Color(0xFFE11D48)),
  'schedule':       (Icons.schedule_rounded,           Color(0xFF0891B2)),
  'verified':       (Icons.verified_rounded,           Color(0xFF2563EB)),
};

/// Model data maklumat (pengumuman)
class MaklumatItem {
  final int id;
  final String judul;
  final String deskripsi;
  final String kategori;
  final String prioritas;
  final String targetAudience;
  final String icon;
  final String? imageUrl;
  final String? pdfUrl;
  final String createdAt;
  final String? className;
  final String? guruName;

  MaklumatItem({
    required this.id,
    required this.judul,
    required this.deskripsi,
    this.kategori = 'Info',
    this.prioritas = 'Sedang',
    this.targetAudience = 'keduanya',
    this.icon = 'campaign',
    this.imageUrl,
    this.pdfUrl,
    required this.createdAt,
    this.className,
    this.guruName,
  });

  factory MaklumatItem.fromJson(Map<String, dynamic> json) {
    return MaklumatItem(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      judul: json['judul'] as String? ?? '',
      deskripsi: json['deskripsi'] as String? ?? '',
      kategori: json['kategori'] as String? ?? 'Info',
      prioritas: json['prioritas'] as String? ?? 'Sedang',
      targetAudience: json['target_audience'] as String? ?? 'keduanya',
      icon: json['icon'] as String? ?? 'campaign',
      imageUrl: json['image_url'] as String?,
      pdfUrl: json['pdf_url'] as String?,
      createdAt: json['created_at'] as String? ?? '',
      className: json['class_name'] as String?,
      guruName: json['guru_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'judul': judul,
        'deskripsi': deskripsi,
        'kategori': kategori,
        'prioritas': prioritas,
        'target_audience': targetAudience,
        'icon': icon,
        'image_url': imageUrl,
        'pdf_url': pdfUrl,
        'created_at': createdAt,
        'class_name': className,
        'guru_name': guruName,
      };

  /// Warna kategori berdasarkan nama kategori
  Color get categoryColor {
    switch (kategori.toLowerCase()) {
      case 'acara':
        return const Color(0xFF1B8A4A); // primaryGreen
      case 'akademik':
        return const Color(0xFF3B82F6); // softBlue
      case 'info':
        return const Color(0xFFEF4444); // red
      default:
        return const Color(0xFF94A39A); // grey
    }
  }

  /// Icon kategori
  IconData get categoryIcon {
    switch (kategori.toLowerCase()) {
      case 'acara':
        return Icons.event_rounded;
      case 'akademik':
        return Icons.school_rounded;
      case 'info':
        return Icons.info_outline_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  /// Icon custom yang dipilih guru — fallback ke categoryIcon
  IconData get iconData => maklumatIconMap[icon]?.$1 ?? categoryIcon;

  /// Warna accent untuk icon custom
  Color get iconColor => maklumatIconMap[icon]?.$2 ?? categoryColor;

  /// Format tanggal untuk tampilan
  String get formattedDate {
    try {
      final dt = DateTime.parse(createdAt);
      final months = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
        'Jul', 'Agt', 'Sep', 'Okt', 'Nov', 'Des'
      ];
      return '${dt.day} ${months[dt.month]} ${dt.year}';
    } catch (_) {
      return createdAt;
    }
  }
}

/// Service untuk fitur Maklumat – sinkron ke server, fallback ke cache lokal.
class MaklumatService {
  static const String _baseUrl = 'https://portal-smalka.com/api';
  static const String _guruCacheKey = 'maklumat_guru_list';
  static const String _studentCacheKey = 'maklumat_student_list';

  // ═══════════════════════════════════════
  // GET: Daftar maklumat guru
  // ═══════════════════════════════════════
  static Future<List<MaklumatItem>> getGuruMaklumat() async {
    try {
      final token = await AuthService.getToken();
      final response = await http.get(
        Uri.parse('$_baseUrl/maklumat.php?action=list'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        final List<dynamic> dataList = body['data'] ?? [];
        final items = dataList.map((e) => MaklumatItem.fromJson(e)).toList();

        await _saveToCache(_guruCacheKey, items);
        return items;
      }
    } on TimeoutException {
      debugPrint('Maklumat: timeout, pakai cache lokal');
    } catch (e) {
      debugPrint('Maklumat: gagal fetch ($e), pakai cache lokal');
    }

    return _getFromCache(_guruCacheKey);
  }

  // ═══════════════════════════════════════
  // GET: Daftar maklumat untuk siswa/ortu
  // ═══════════════════════════════════════
  static Future<List<MaklumatItem>> getStudentMaklumat({int? studentId}) async {
    try {
      final token = await AuthService.getToken();
      String url = '$_baseUrl/maklumat.php?action=student_list';
      if (studentId != null) {
        url += '&student_id=$studentId';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        final List<dynamic> dataList = body['data'] ?? [];
        final items = dataList.map((e) => MaklumatItem.fromJson(e)).toList();

        await _saveToCache(_studentCacheKey, items);
        return items;
      }
    } on TimeoutException {
      debugPrint('Maklumat (student): timeout, pakai cache lokal');
    } catch (e) {
      debugPrint('Maklumat (student): gagal fetch ($e), pakai cache lokal');
    }

    return _getFromCache(_studentCacheKey);
  }

  // ═══════════════════════════════════════
  // POST: Buat maklumat baru
  // ═══════════════════════════════════════
  static Future<int> createMaklumat({
    required String judul,
    required String deskripsi,
    String kategori = 'Info',
    String prioritas = 'Sedang',
    String targetAudience = 'keduanya',
    String icon = 'campaign',
    String? imageUrl,
    String? pdfUrl,
  }) async {
    try {
      final token = await AuthService.getToken();
      final response = await http.post(
        Uri.parse('$_baseUrl/maklumat.php'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'judul': judul,
          'deskripsi': deskripsi,
          'kategori': kategori,
          'prioritas': prioritas,
          'target_audience': targetAudience,
          'icon': icon,
          'image_url': imageUrl,
          'pdf_url': pdfUrl,
        }),
      ).timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && body['success'] == true) {
        final rawId = body['data']?['id'];
        return rawId is int ? rawId : int.tryParse(rawId.toString()) ?? 0;
      }
      throw Exception(body['message'] ?? 'Gagal menyimpan');
    } catch (e) {
      debugPrint('Maklumat createMaklumat gagal: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════
  // DELETE: Hapus maklumat
  // ═══════════════════════════════════════
  static Future<void> deleteMaklumat(int id) async {
    try {
      final token = await AuthService.getToken();
      final response = await http.delete(
        Uri.parse('$_baseUrl/maklumat.php?id=$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && body['success'] == true) {
        return;
      }
      throw Exception(body['message'] ?? 'Gagal menghapus');
    } catch (e) {
      debugPrint('Maklumat deleteMaklumat gagal: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════
  // Cache helpers
  // ═══════════════════════════════════════
  static Future<List<MaklumatItem>> _getFromCache(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(key);
    if (jsonStr == null || jsonStr.isEmpty) return [];

    final List<dynamic> jsonList = jsonDecode(jsonStr);
    return jsonList.map((e) => MaklumatItem.fromJson(e)).toList();
  }

  static Future<void> _saveToCache(String key, List<MaklumatItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(items.map((i) => i.toJson()).toList());
    await prefs.setString(key, jsonStr);
  }
}
