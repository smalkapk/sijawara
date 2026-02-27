import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

// ═══════════════════════════════════════
// Surah name lookup (shared reference)
// ═══════════════════════════════════════
const Map<int, String> surahNames = {
  1: 'Al-Fatihah', 2: 'Al-Baqarah', 3: "Ali 'Imran", 4: "An-Nisa'",
  5: "Al-Ma'idah", 6: "Al-An'am", 7: "Al-A'raf", 8: 'Al-Anfal',
  9: 'At-Taubah', 10: 'Yunus', 11: 'Hud', 12: 'Yusuf',
  13: "Ar-Ra'd", 14: 'Ibrahim', 15: 'Al-Hijr', 16: 'An-Nahl',
  17: "Al-Isra'", 18: 'Al-Kahf', 19: 'Maryam', 20: 'Taha',
  21: "Al-Anbiya'", 22: 'Al-Hajj', 23: "Al-Mu'minun", 24: 'An-Nur',
  25: 'Al-Furqan', 26: "Asy-Syu'ara'", 27: 'An-Naml', 28: 'Al-Qasas',
  29: "Al-'Ankabut", 30: 'Ar-Rum', 31: 'Luqman', 32: 'As-Sajdah',
  33: 'Al-Ahzab', 34: "Saba'", 35: 'Fatir', 36: 'Yasin',
  37: 'As-Saffat', 38: 'Sad', 39: 'Az-Zumar', 40: 'Ghafir',
  41: 'Fussilat', 42: 'Asy-Syura', 43: 'Az-Zukhruf', 44: 'Ad-Dukhan',
  45: 'Al-Jasiyah', 46: 'Al-Ahqaf', 47: 'Muhammad', 48: 'Al-Fath',
  49: 'Al-Hujurat', 50: 'Qaf', 51: 'Az-Zariyat', 52: 'At-Tur',
  53: 'An-Najm', 54: 'Al-Qamar', 55: 'Ar-Rahman', 56: "Al-Waqi'ah",
  57: 'Al-Hadid', 58: 'Al-Mujadalah', 59: 'Al-Hasyr', 60: 'Al-Mumtahanah',
  61: 'As-Saff', 62: "Al-Jumu'ah", 63: 'Al-Munafiqun', 64: 'At-Tagabun',
  65: 'At-Talaq', 66: 'At-Tahrim', 67: 'Al-Mulk', 68: 'Al-Qalam',
  69: 'Al-Haqqah', 70: "Al-Ma'arij", 71: 'Nuh', 72: 'Al-Jinn',
  73: 'Al-Muzzammil', 74: 'Al-Muddassir', 75: 'Al-Qiyamah', 76: 'Al-Insan',
  77: 'Al-Mursalat', 78: "An-Naba'", 79: "An-Nazi'at", 80: "'Abasa",
  81: 'At-Takwir', 82: 'Al-Infitar', 83: 'Al-Mutaffifin', 84: 'Al-Insyiqaq',
  85: 'Al-Buruj', 86: 'At-Tariq', 87: "Al-A'la", 88: 'Al-Gasiyah',
  89: 'Al-Fajr', 90: 'Al-Balad', 91: 'Asy-Syams', 92: 'Al-Lail',
  93: 'Ad-Duha', 94: 'Asy-Syarh', 95: 'At-Tin', 96: "Al-'Alaq",
  97: 'Al-Qadr', 98: 'Al-Bayyinah', 99: 'Az-Zalzalah', 100: "Al-'Adiyat",
  101: "Al-Qari'ah", 102: 'At-Takasur', 103: "Al-'Asr", 104: 'Al-Humazah',
  105: 'Al-Fil', 106: 'Quraisy', 107: "Al-Ma'un", 108: 'Al-Kausar',
  109: 'Al-Kafirun', 110: 'An-Nasr', 111: 'Al-Lahab', 112: 'Al-Ikhlas',
  113: 'Al-Falaq', 114: 'An-Nas',
};

/// Mencari surah number berdasarkan nama (case-insensitive, partial match).
int? findSurahNumber(String name) {
  final lower = name.toLowerCase().trim();
  for (final entry in surahNames.entries) {
    if (entry.value.toLowerCase() == lower) return entry.key;
  }
  // Partial match fallback
  for (final entry in surahNames.entries) {
    if (entry.value.toLowerCase().contains(lower)) return entry.key;
  }
  return null;
}

// ═══════════════════════════════════════
// Model: Kelas
// ═══════════════════════════════════════
class TahfidzClass {
  final int id;
  final String name;
  final String academicYear;
  final int studentCount;

  TahfidzClass({
    required this.id,
    required this.name,
    this.academicYear = '',
    this.studentCount = 0,
  });

  factory TahfidzClass.fromJson(Map<String, dynamic> json) {
    return TahfidzClass(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      name: json['name'] as String? ?? '',
      academicYear: json['academic_year'] as String? ?? '',
      studentCount: json['student_count'] is int
          ? json['student_count']
          : int.tryParse(json['student_count']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'academic_year': academicYear,
        'student_count': studentCount,
      };
}

// ═══════════════════════════════════════
// Model: Siswa
// ═══════════════════════════════════════
class TahfidzStudent {
  final int studentId;
  final String nis;
  final String name;
  final String className;

  TahfidzStudent({
    required this.studentId,
    required this.nis,
    required this.name,
    this.className = '',
  });

  factory TahfidzStudent.fromJson(Map<String, dynamic> json) {
    return TahfidzStudent(
      studentId: json['student_id'] is int
          ? json['student_id']
          : int.parse(json['student_id'].toString()),
      nis: json['nis']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      className: json['class_name'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'student_id': studentId,
        'nis': nis,
        'name': name,
        'class_name': className,
      };
}

// ═══════════════════════════════════════
// Model: Setoran
// ═══════════════════════════════════════
class TahfidzSetoran {
  final String id;
  final int surahNumber;
  final int ayatFrom;
  final int ayatTo;
  final String grade;       // A, B+, B, C, D
  final String gradeLabel;  // Mumtaz, Jayyid Jiddan, dst
  final String notes;
  final int points;
  final String guruName;
  final DateTime setoranAt;

  TahfidzSetoran({
    required this.id,
    required this.surahNumber,
    required this.ayatFrom,
    required this.ayatTo,
    this.grade = 'C',
    this.gradeLabel = '',
    this.notes = '',
    this.points = 0,
    this.guruName = '',
    DateTime? setoranAt,
  }) : setoranAt = setoranAt ?? DateTime.now();

  /// Nama surah dari lookup
  String get surahName => surahNames[surahNumber] ?? 'Surah $surahNumber';

  /// Range ayat terformat: "1-10" atau "1-7" dst
  String get ayatRange => '$ayatFrom-$ayatTo';

  factory TahfidzSetoran.fromJson(Map<String, dynamic> json) {
    return TahfidzSetoran(
      id: json['id']?.toString() ?? '',
      surahNumber: json['surah_number'] is int
          ? json['surah_number']
          : int.parse(json['surah_number'].toString()),
      ayatFrom: json['ayat_from'] is int
          ? json['ayat_from']
          : int.parse(json['ayat_from'].toString()),
      ayatTo: json['ayat_to'] is int
          ? json['ayat_to']
          : int.parse(json['ayat_to'].toString()),
      grade: json['grade'] as String? ?? 'C',
      gradeLabel: json['grade_label'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      points: json['points'] is int
          ? json['points']
          : int.tryParse(json['points']?.toString() ?? '0') ?? 0,
      guruName: json['guru_name'] as String? ?? '',
      setoranAt: json['setoran_at'] != null
          ? DateTime.parse(json['setoran_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'surah_number': surahNumber,
        'ayat_from': ayatFrom,
        'ayat_to': ayatTo,
        'grade': grade,
        'grade_label': gradeLabel,
        'notes': notes,
        'points': points,
        'guru_name': guruName,
        'setoran_at': setoranAt.toIso8601String(),
      };
}

// ═══════════════════════════════════════
// Service
// ═══════════════════════════════════════
class TahfidzService {
  static const String _baseUrl = 'https://portal-smalka.com/api';
  static const String _classesCacheKey = 'tahfidz_classes';
  static const String _classStudentsCachePrefix = 'tahfidz_class_students_';
  static const String _studentsCacheKey = 'tahfidz_students';
  static const String _reportsCachePrefix = 'tahfidz_reports_';
  static const String _mySetoranCacheKey = 'tahfidz_my_setoran';

  // ── GET: Daftar kelas (guru_tahfidz) ──
  static Future<List<TahfidzClass>> getClasses() async {
    try {
      final token = await AuthService.getToken();
      final response = await http.get(
        Uri.parse('$_baseUrl/tahfidz.php?action=classes'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint('Tahfidz classes: status=${response.statusCode} body=${response.body}');

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && body['success'] == true) {
        final List<dynamic> dataList = body['data'] ?? [];
        final classes = dataList.map((e) => TahfidzClass.fromJson(e)).toList();
        await _saveClassesToCache(classes);
        return classes;
      }
      final msg = body['message'] ?? 'Gagal mengambil data kelas (${response.statusCode})';
      throw Exception(msg);
    } on TimeoutException {
      debugPrint('Tahfidz: timeout classes, pakai cache');
      return _getClassesFromCache();
    } catch (e) {
      debugPrint('Tahfidz: gagal fetch classes ($e)');
      final cached = await _getClassesFromCache();
      if (cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  // ── GET: Daftar siswa per kelas (guru_tahfidz) ──
  static Future<List<TahfidzStudent>> getStudentsByClass({
    required int classId,
  }) async {
    try {
      final token = await AuthService.getToken();
      final response = await http.get(
        Uri.parse('$_baseUrl/tahfidz.php?action=class_students&class_id=$classId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint('Tahfidz class_students: status=${response.statusCode} body=${response.body}');

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && body['success'] == true) {
        final List<dynamic> dataList = body['data'] ?? [];
        final students = dataList.map((e) => TahfidzStudent.fromJson(e)).toList();
        await _saveClassStudentsToCache(classId, students);
        return students;
      }
      final msg = body['message'] ?? 'Gagal mengambil data siswa (${response.statusCode})';
      throw Exception(msg);
    } on TimeoutException {
      debugPrint('Tahfidz: timeout class_students, pakai cache');
      return _getClassStudentsFromCache(classId);
    } catch (e) {
      debugPrint('Tahfidz: gagal fetch class_students ($e)');
      final cached = await _getClassStudentsFromCache(classId);
      if (cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  // ── GET: Daftar siswa (guru) ──
  static Future<List<TahfidzStudent>> getStudents() async {
    try {
      final token = await AuthService.getToken();
      final response = await http.get(
        Uri.parse('$_baseUrl/tahfidz.php?action=students'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint('Tahfidz students: status=${response.statusCode} body=${response.body}');

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && body['success'] == true) {
        final List<dynamic> dataList = body['data'] ?? [];
        final students =
            dataList.map((e) => TahfidzStudent.fromJson(e)).toList();
        await _saveStudentsToCache(students);
        return students;
      }
      // API returned error — throw so UI can show message
      final msg = body['message'] ?? 'Gagal mengambil data siswa (${response.statusCode})';
      throw Exception(msg);
    } on TimeoutException {
      debugPrint('Tahfidz: timeout, pakai cache');
      return _getStudentsFromCache();
    } catch (e) {
      debugPrint('Tahfidz: gagal fetch siswa ($e)');
      // Try cache fallback, but if cache is also empty rethrow
      final cached = await _getStudentsFromCache();
      if (cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  // ── GET: Riwayat setoran siswa (guru) ──
  static Future<List<TahfidzSetoran>> getReports({
    required int studentId,
  }) async {
    try {
      final token = await AuthService.getToken();
      final uri = Uri.parse(
        '$_baseUrl/tahfidz.php?action=reports&student_id=$studentId',
      );
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && body['success'] == true) {
        final List<dynamic> dataList = body['data'] ?? [];
        final reports =
            dataList.map((e) => TahfidzSetoran.fromJson(e)).toList();
        await _saveReportsToCache(studentId, reports);
        return reports;
      }
    } on TimeoutException {
      debugPrint('Tahfidz: timeout reports, pakai cache');
    } catch (e) {
      debugPrint('Tahfidz: gagal fetch reports ($e), pakai cache');
    }
    return _getReportsFromCache(studentId);
  }

  // ── GET: Riwayat setoran sendiri (siswa) ──
  static Future<List<TahfidzSetoran>> getMySetoran() async {
    try {
      final token = await AuthService.getToken();
      final response = await http.get(
        Uri.parse('$_baseUrl/tahfidz.php?action=my_setoran'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && body['success'] == true) {
        final List<dynamic> dataList = body['data'] ?? [];
        final reports =
            dataList.map((e) => TahfidzSetoran.fromJson(e)).toList();
        await _saveMySetoranToCache(reports);
        return reports;
      }
    } on TimeoutException {
      debugPrint('Tahfidz: timeout my_setoran, pakai cache');
    } catch (e) {
      debugPrint('Tahfidz: gagal fetch my_setoran ($e), pakai cache');
    }
    return _getMySetoranFromCache();
  }

  // ── POST: Simpan setoran baru ──
  static Future<String> addSetoran({
    required int studentId,
    required int surahNumber,
    required int ayatFrom,
    required int ayatTo,
    required String grade,
    String notes = '',
  }) async {
    try {
      final token = await AuthService.getToken();
      final response = await http.post(
        Uri.parse('$_baseUrl/tahfidz.php'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'student_id': studentId,
          'surah_number': surahNumber,
          'ayat_from': ayatFrom,
          'ayat_to': ayatTo,
          'grade': grade,
          'notes': notes,
        }),
      ).timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && body['success'] == true) {
        return body['data']?['id']?.toString() ?? '';
      }
      throw Exception(body['message'] ?? 'Gagal menyimpan setoran');
    } catch (e) {
      debugPrint('Tahfidz addSetoran gagal: $e');
      rethrow;
    }
  }

  // ── POST: Update setoran ──
  static Future<void> updateSetoran({
    required String id,
    required int studentId,
    required int surahNumber,
    required int ayatFrom,
    required int ayatTo,
    required String grade,
    String notes = '',
  }) async {
    try {
      final token = await AuthService.getToken();
      final response = await http.post(
        Uri.parse('$_baseUrl/tahfidz.php'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'id': id,
          'student_id': studentId,
          'surah_number': surahNumber,
          'ayat_from': ayatFrom,
          'ayat_to': ayatTo,
          'grade': grade,
          'notes': notes,
        }),
      ).timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && body['success'] == true) {
        return;
      }
      throw Exception(body['message'] ?? 'Gagal memperbarui setoran');
    } catch (e) {
      debugPrint('Tahfidz updateSetoran gagal: $e');
      rethrow;
    }
  }

  // ── DELETE: Hapus setoran ──
  static Future<void> deleteSetoran(String id) async {
    try {
      final token = await AuthService.getToken();
      final response = await http.delete(
        Uri.parse('$_baseUrl/tahfidz.php?id=$id'),
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
      debugPrint('Tahfidz deleteSetoran gagal: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════
  // Cache helpers – Classes
  // ═══════════════════════════════════════
  static Future<void> _saveClassesToCache(List<TahfidzClass> classes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = classes.map((c) => c.toJson()).toList();
      await prefs.setString(_classesCacheKey, jsonEncode(jsonList));
    } catch (_) {}
  }

  static Future<List<TahfidzClass>> _getClassesFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_classesCacheKey);
      if (raw == null) return [];
      final List<dynamic> list = jsonDecode(raw);
      return list.map((e) => TahfidzClass.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  // ═══════════════════════════════════════
  // Cache helpers – Class Students (per class)
  // ═══════════════════════════════════════
  static Future<void> _saveClassStudentsToCache(
      int classId, List<TahfidzStudent> students) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = students.map((s) => s.toJson()).toList();
      await prefs.setString(
          '$_classStudentsCachePrefix$classId', jsonEncode(jsonList));
    } catch (_) {}
  }

  static Future<List<TahfidzStudent>> _getClassStudentsFromCache(
      int classId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_classStudentsCachePrefix$classId');
      if (raw == null) return [];
      final List<dynamic> list = jsonDecode(raw);
      return list.map((e) => TahfidzStudent.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  // ═══════════════════════════════════════
  // Cache helpers – Students
  // ═══════════════════════════════════════
  static Future<void> _saveStudentsToCache(List<TahfidzStudent> students) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = students.map((s) => s.toJson()).toList();
      await prefs.setString(_studentsCacheKey, jsonEncode(jsonList));
    } catch (_) {}
  }

  static Future<List<TahfidzStudent>> _getStudentsFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_studentsCacheKey);
      if (raw == null) return [];
      final List<dynamic> list = jsonDecode(raw);
      return list.map((e) => TahfidzStudent.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  // ═══════════════════════════════════════
  // Cache helpers – Reports (per student)
  // ═══════════════════════════════════════
  static Future<void> _saveReportsToCache(
      int studentId, List<TahfidzSetoran> reports) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = reports.map((r) => r.toJson()).toList();
      await prefs.setString(
          '$_reportsCachePrefix$studentId', jsonEncode(jsonList));
    } catch (_) {}
  }

  static Future<List<TahfidzSetoran>> _getReportsFromCache(
      int studentId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_reportsCachePrefix$studentId');
      if (raw == null) return [];
      final List<dynamic> list = jsonDecode(raw);
      return list.map((e) => TahfidzSetoran.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  // ═══════════════════════════════════════
  // Cache helpers – My Setoran (siswa)
  // ═══════════════════════════════════════
  static Future<void> _saveMySetoranToCache(
      List<TahfidzSetoran> reports) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = reports.map((r) => r.toJson()).toList();
      await prefs.setString(_mySetoranCacheKey, jsonEncode(jsonList));
    } catch (_) {}
  }

  static Future<List<TahfidzSetoran>> _getMySetoranFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_mySetoranCacheKey);
      if (raw == null) return [];
      final List<dynamic> list = jsonDecode(raw);
      return list.map((e) => TahfidzSetoran.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  // ═══════════════════════════════════════
  // GET: Riwayat setoran anak (wali / orang_tua)
  // ═══════════════════════════════════════
  static const String _waliSetoranCachePrefix = 'tahfidz_wali_setoran_';

  static Future<List<TahfidzSetoran>> getWaliSetoran({int? studentId}) async {
    try {
      final token = await AuthService.getToken();
      String url = '$_baseUrl/tahfidz.php?action=wali_setoran';
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
        final reports =
            dataList.map((e) => TahfidzSetoran.fromJson(e)).toList();
        await _saveWaliSetoranToCache(studentId ?? 0, reports);
        return reports;
      }
    } on TimeoutException {
      debugPrint('Tahfidz: timeout wali_setoran, pakai cache');
    } catch (e) {
      debugPrint('Tahfidz: gagal fetch wali_setoran ($e), pakai cache');
    }
    return _getWaliSetoranFromCache(studentId ?? 0);
  }

  static Future<void> _saveWaliSetoranToCache(
      int studentId, List<TahfidzSetoran> reports) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = reports.map((r) => r.toJson()).toList();
      await prefs.setString(
          '$_waliSetoranCachePrefix$studentId', jsonEncode(jsonList));
    } catch (_) {}
  }

  static Future<List<TahfidzSetoran>> _getWaliSetoranFromCache(
      int studentId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_waliSetoranCachePrefix$studentId');
      if (raw == null) return [];
      final List<dynamic> list = jsonDecode(raw);
      return list.map((e) => TahfidzSetoran.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }
}
