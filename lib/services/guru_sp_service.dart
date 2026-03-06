import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

// ═══════════════════════════════════════
// Model: Siswa (untuk daftar siswa guru)
// ═══════════════════════════════════════

class GuruSpStudent {
  final int studentId;
  final String nis;
  final String name;
  final String className;

  GuruSpStudent({
    required this.studentId,
    required this.nis,
    required this.name,
    required this.className,
  });

  factory GuruSpStudent.fromJson(Map<String, dynamic> json) {
    return GuruSpStudent(
      studentId: json['student_id'] is int
          ? json['student_id']
          : int.tryParse(json['student_id']?.toString() ?? '0') ?? 0,
      nis: json['nis']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      className: json['class_name']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'student_id': studentId,
        'nis': nis,
        'name': name,
        'class_name': className,
      };
}

// ═══════════════════════════════════════
// Model: Laporan SP
// ═══════════════════════════════════════

class GuruSpReport {
  final String id;
  final String date; // format: dd-MM-yyyy
  final String jenisSp;
  final String alasan;
  final String tindakan;
  final String note;
  final String guruName;
  final String createdAt;

  GuruSpReport({
    required this.id,
    required this.date,
    required this.jenisSp,
    required this.alasan,
    this.tindakan = '',
    this.note = '',
    this.guruName = '',
    this.createdAt = '',
  });

  factory GuruSpReport.fromJson(Map<String, dynamic> json) {
    return GuruSpReport(
      id: json['id']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      jenisSp: json['jenis_sp']?.toString() ?? '',
      alasan: json['alasan']?.toString() ?? '',
      tindakan: json['tindakan']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
      guruName: json['guru_name']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'date': date,
        'jenis_sp': jenisSp,
        'alasan': alasan,
        'tindakan': tindakan,
        'note': note,
      };
}

// ═══════════════════════════════════════
// Service
// ═══════════════════════════════════════

class GuruSpService {
  static const String _baseUrl = 'https://portal-smalka.com/api';

  /// GET: Ambil daftar siswa yang diajar guru
  static Future<List<GuruSpStudent>> getStudents() async {
    try {
      final token = await AuthService.getToken();
      final uri = Uri.parse('$_baseUrl/guru_sp.php?action=students');
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
        return dataList.map((e) => GuruSpStudent.fromJson(e)).toList();
      }
      throw Exception(body['message'] ?? 'Gagal mengambil daftar siswa');
    } on TimeoutException {
      debugPrint('GuruSp: timeout getStudents');
      rethrow;
    } catch (e) {
      debugPrint('GuruSp: gagal fetch students ($e)');
      rethrow;
    }
  }

  /// GET: Ambil laporan SP per siswa
  static Future<List<GuruSpReport>> getReports({
    required int studentId,
  }) async {
    try {
      final token = await AuthService.getToken();
      final uri = Uri.parse(
        '$_baseUrl/guru_sp.php?action=reports&student_id=$studentId',
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
        return dataList.map((e) => GuruSpReport.fromJson(e)).toList();
      }
      throw Exception(body['message'] ?? 'Gagal mengambil laporan SP');
    } on TimeoutException {
      debugPrint('GuruSp: timeout getReports');
      rethrow;
    } catch (e) {
      debugPrint('GuruSp: gagal fetch reports ($e)');
      rethrow;
    }
  }

  /// POST: Simpan laporan SP baru
  static Future<String?> addReport({
    required int studentId,
    required String spDate,
    required String jenisSp,
    required String alasan,
    String tindakan = '',
    String note = '',
  }) async {
    try {
      final token = await AuthService.getToken();
      final response = await http.post(
        Uri.parse('$_baseUrl/guru_sp.php'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'student_id': studentId,
          'sp_date': spDate,
          'jenis_sp': jenisSp,
          'alasan': alasan,
          'tindakan': tindakan,
          'note': note,
        }),
      ).timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && body['success'] == true) {
        return body['data']?['id']?.toString();
      }
      throw Exception(body['message'] ?? 'Gagal menyimpan');
    } catch (e) {
      debugPrint('GuruSp addReport gagal: $e');
      rethrow;
    }
  }

  /// POST: Update laporan SP
  static Future<void> updateReport({
    required String reportId,
    required int studentId,
    required String spDate,
    required String jenisSp,
    required String alasan,
    String tindakan = '',
    String note = '',
  }) async {
    try {
      final token = await AuthService.getToken();
      final response = await http.post(
        Uri.parse('$_baseUrl/guru_sp.php'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'id': reportId,
          'student_id': studentId,
          'sp_date': spDate,
          'jenis_sp': jenisSp,
          'alasan': alasan,
          'tindakan': tindakan,
          'note': note,
        }),
      ).timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && body['success'] == true) {
        return;
      }
      throw Exception(body['message'] ?? 'Gagal memperbarui');
    } catch (e) {
      debugPrint('GuruSp updateReport gagal: $e');
      rethrow;
    }
  }

  /// DELETE: Hapus laporan SP
  static Future<void> deleteReport(String id) async {
    try {
      final token = await AuthService.getToken();
      final response = await http.delete(
        Uri.parse('$_baseUrl/guru_sp.php?id=$id'),
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
      debugPrint('GuruSp deleteReport gagal: $e');
      rethrow;
    }
  }
}
