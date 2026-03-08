import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

/// Model data siswa untuk daftar siswa guru tugas
class GuruTugasStudent {
  final int studentId;
  final String nis;
  final String name;
  final String className;
  final String? avatarUrl;

  GuruTugasStudent({
    required this.studentId,
    required this.nis,
    required this.name,
    this.className = '',
    this.avatarUrl,
  });

  factory GuruTugasStudent.fromJson(Map<String, dynamic> json) {
    return GuruTugasStudent(
      studentId: json['student_id'] is int
          ? json['student_id']
          : int.parse(json['student_id'].toString()),
      nis: json['nis']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      className: json['class_name'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'student_id': studentId,
        'nis': nis,
        'name': name,
        'class_name': className,
        'avatar_url': avatarUrl ?? '',
      };
}

/// Model data laporan tugas
class GuruTugasReport {
  final String id;
  final DateTime date;
  final String judul;
  final String materi;
  final String mentor;
  final String note;
  final String subject;
  final DateTime createdAt;

  GuruTugasReport({
    required this.id,
    required this.date,
    this.judul = '',
    required this.materi,
    this.mentor = '',
    this.note = '',
    this.subject = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory GuruTugasReport.fromJson(Map<String, dynamic> json) {
    return GuruTugasReport(
      id: json['id']?.toString() ?? '',
      date: DateTime.parse(json['date'] as String),
      judul: json['judul'] as String? ?? '',
      materi: json['materi'] as String? ?? '',
      mentor: json['mentor'] as String? ?? '',
      note: json['note'] as String? ?? '',
      subject: json['subject'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String().substring(0, 10),
        'judul': judul,
        'materi': materi,
        'mentor': mentor,
        'note': note,
        'subject': subject,
        'created_at': createdAt.toIso8601String(),
      };

  GuruTugasReport copyWith({
    String? id,
    DateTime? date,
    String? judul,
    String? materi,
    String? mentor,
    String? note,
    String? subject,
    DateTime? createdAt,
  }) {
    return GuruTugasReport(
      id: id ?? this.id,
      date: date ?? this.date,
      judul: judul ?? this.judul,
      materi: materi ?? this.materi,
      mentor: mentor ?? this.mentor,
      note: note ?? this.note,
      subject: subject ?? this.subject,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Service untuk fitur Guru Tugas – sinkron ke server, fallback ke cache lokal.
class GuruTugasService {
  static const String _baseUrl = 'https://portal-smalka.com/api';
  static const String _studentsCacheKey = 'guru_tugas_students';
  static const String _reportsCachePrefix = 'guru_tugas_reports_';

  // ═══════════════════════════════════════
  // GET: Ambil daftar siswa
  // ═══════════════════════════════════════
  static Future<List<GuruTugasStudent>> getStudents() async {
    try {
      final token = await AuthService.getToken();
      final response = await http.get(
        Uri.parse('$_baseUrl/guru_tugas.php?action=students'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        final List<dynamic> dataList = body['data'] ?? [];
        final students =
            dataList.map((e) => GuruTugasStudent.fromJson(e)).toList();

        // Simpan ke cache lokal
        await _saveStudentsToCache(students);
        return students;
      }
    } on TimeoutException {
      debugPrint('GuruTugas: timeout, pakai cache lokal');
    } catch (e) {
      debugPrint('GuruTugas: gagal fetch siswa ($e), pakai cache lokal');
    }

    return _getStudentsFromCache();
  }

  // ═══════════════════════════════════════
  // GET: Ambil laporan tugas per siswa
  // ═══════════════════════════════════════
  static Future<List<GuruTugasReport>> getReports({
    required int studentId,
    required String subject,
  }) async {
    try {
      final token = await AuthService.getToken();
      final uri = Uri.parse(
        '$_baseUrl/guru_tugas.php?action=reports&student_id=$studentId&subject=${Uri.encodeComponent(subject)}',
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
            dataList.map((e) => GuruTugasReport.fromJson(e)).toList();
        reports.sort((a, b) => b.date.compareTo(a.date));

        await _saveReportsToCache(studentId, subject, reports);
        return reports;
      }
    } on TimeoutException {
      debugPrint('GuruTugas: timeout reports, pakai cache lokal');
    } catch (e) {
      debugPrint('GuruTugas: gagal fetch reports ($e), pakai cache lokal');
    }

    return _getReportsFromCache(studentId, subject);
  }

  // ═══════════════════════════════════════
  // POST: Simpan laporan tugas baru
  // ═══════════════════════════════════════
  static Future<String?> addReport({
    required int studentId,
    required String subject,
    required GuruTugasReport report,
  }) async {
    try {
      final token = await AuthService.getToken();
      final response = await http.post(
        Uri.parse('$_baseUrl/guru_tugas.php'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'student_id': studentId,
          'subject': subject,
          'date': report.date.toIso8601String().substring(0, 10),
          'judul': report.judul,
          'materi': report.materi,
          'mentor': report.mentor,
          'note': report.note,
        }),
      ).timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && body['success'] == true) {
        return body['data']?['id']?.toString();
      }
      throw Exception(body['message'] ?? 'Gagal menyimpan');
    } catch (e) {
      debugPrint('GuruTugas addReport gagal: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════
  // POST: Update laporan tugas
  // ═══════════════════════════════════════
  static Future<void> updateReport({
    required int studentId,
    required String subject,
    required GuruTugasReport report,
  }) async {
    try {
      final token = await AuthService.getToken();
      final response = await http.post(
        Uri.parse('$_baseUrl/guru_tugas.php'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'id': report.id,
          'student_id': studentId,
          'subject': subject,
          'date': report.date.toIso8601String().substring(0, 10),
          'judul': report.judul,
          'materi': report.materi,
          'mentor': report.mentor,
          'note': report.note,
        }),
      ).timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && body['success'] == true) {
        return;
      }
      throw Exception(body['message'] ?? 'Gagal memperbarui');
    } catch (e) {
      debugPrint('GuruTugas updateReport gagal: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════
  // DELETE: Hapus laporan tugas
  // ═══════════════════════════════════════
  static Future<void> deleteReport(String id, {required String subject}) async {
    try {
      final token = await AuthService.getToken();
      final response = await http.delete(
        Uri.parse(
            '$_baseUrl/guru_tugas.php?id=$id&subject=${Uri.encodeComponent(subject)}'),
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
      debugPrint('GuruTugas deleteReport gagal: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════
  // Cache helpers – Students
  // ═══════════════════════════════════════
  static Future<List<GuruTugasStudent>> _getStudentsFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_studentsCacheKey);
    if (jsonStr == null || jsonStr.isEmpty) return [];

    final List<dynamic> jsonList = jsonDecode(jsonStr);
    return jsonList.map((e) => GuruTugasStudent.fromJson(e)).toList();
  }

  static Future<void> _saveStudentsToCache(
      List<GuruTugasStudent> students) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(students.map((s) => s.toJson()).toList());
    await prefs.setString(_studentsCacheKey, jsonStr);
  }

  // ═══════════════════════════════════════
  // Cache helpers – Reports
  // ═══════════════════════════════════════
  static String _reportsCacheKey(int studentId, String subject) =>
      '${_reportsCachePrefix}${studentId}_$subject';

  static Future<List<GuruTugasReport>> _getReportsFromCache(
      int studentId, String subject) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_reportsCacheKey(studentId, subject));
    if (jsonStr == null || jsonStr.isEmpty) return [];

    final List<dynamic> jsonList = jsonDecode(jsonStr);
    final reports =
        jsonList.map((e) => GuruTugasReport.fromJson(e)).toList();
    reports.sort((a, b) => b.date.compareTo(a.date));
    return reports;
  }

  static Future<void> _saveReportsToCache(
      int studentId, String subject, List<GuruTugasReport> reports) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(reports.map((r) => r.toJson()).toList());
    await prefs.setString(_reportsCacheKey(studentId, subject), jsonStr);
  }
}
