import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

// ═══════════════════════════════════════
// Model: Evaluasi View (untuk siswa & wali)
// ═══════════════════════════════════════

class EvaluasiViewReport {
  final int id;
  final int studentId;
  final String studentName;
  final String studentNis;
  final String className;
  final String guruName;
  final int evaluasiNumber;
  final String bulan;
  final Map<String, String> nilaiData;
  final Map<String, String> keteranganData;
  final String catatan;
  final DateTime evaluasiDate;
  final DateTime createdAt;

  EvaluasiViewReport({
    required this.id,
    required this.studentId,
    this.studentName = '',
    this.studentNis = '',
    this.className = '',
    this.guruName = '',
    this.evaluasiNumber = 1,
    required this.bulan,
    required this.nilaiData,
    Map<String, String>? keteranganData,
    this.catatan = '',
    required this.evaluasiDate,
    DateTime? createdAt,
  })  : keteranganData = keteranganData ?? {},
        createdAt = createdAt ?? DateTime.now();

  String get title {
    const ordinals = [
      '',
      'Pertama',
      'Kedua',
      'Ketiga',
      'Keempat',
      'Kelima',
      'Keenam',
      'Ketujuh',
      'Kedelapan',
      'Kesembilan',
      'Kesepuluh',
      'Kesebelas',
      'Kedua Belas',
    ];
    final label = (evaluasiNumber > 0 && evaluasiNumber < ordinals.length)
        ? ordinals[evaluasiNumber]
        : 'Ke-$evaluasiNumber';
    return 'Laporan Evaluasi $label';
  }

  factory EvaluasiViewReport.fromJson(Map<String, dynamic> json) {
    Map<String, String> nilai = {};
    if (json['nilai_data'] != null) {
      if (json['nilai_data'] is String) {
        final decoded = jsonDecode(json['nilai_data']);
        if (decoded is Map) {
          nilai = decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
        }
      } else if (json['nilai_data'] is Map) {
        nilai = (json['nilai_data'] as Map)
            .map((k, v) => MapEntry(k.toString(), v.toString()));
      }
    }

    Map<String, String> keterangan = {};
    if (json['keterangan_data'] != null) {
      if (json['keterangan_data'] is String) {
        final decoded = jsonDecode(json['keterangan_data']);
        if (decoded is Map) {
          keterangan =
              decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
        }
      } else if (json['keterangan_data'] is Map) {
        keterangan = (json['keterangan_data'] as Map)
            .map((k, v) => MapEntry(k.toString(), v.toString()));
      }
    }

    return EvaluasiViewReport(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      studentId: json['student_id'] is int
          ? json['student_id']
          : int.tryParse(json['student_id']?.toString() ?? '0') ?? 0,
      studentName: json['student_name']?.toString() ?? '',
      studentNis: json['student_nis']?.toString() ?? '',
      className: json['class_name']?.toString() ?? '',
      guruName: json['guru_name']?.toString() ?? '',
      evaluasiNumber: json['evaluasi_number'] is int
          ? json['evaluasi_number']
          : int.tryParse(json['evaluasi_number']?.toString() ?? '1') ?? 1,
      bulan: json['bulan']?.toString() ?? '',
      nilaiData: nilai,
      keteranganData: keterangan,
      catatan: json['catatan']?.toString() ?? '',
      evaluasiDate: DateTime.tryParse(json['evaluasi_date']?.toString() ?? '') ??
          DateTime.now(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

// ═══════════════════════════════════════
// Service
// ═══════════════════════════════════════

class EvaluasiViewService {
  static const String _baseUrl = 'https://portal-smalka.com/api';

  /// Ambil semua evaluasi (siswa: milik sendiri, wali: anak-anak)
  /// [studentId] opsional filter untuk wali yang punya banyak anak
  static Future<List<EvaluasiViewReport>> getEvaluasiList({
    int? studentId,
  }) async {
    try {
      final token = await AuthService.getToken();
      String url = '$_baseUrl/evaluasi_view.php?action=list';
      if (studentId != null) url += '&student_id=$studentId';

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
        return dataList
            .map((e) => EvaluasiViewReport.fromJson(e))
            .toList();
      }

      throw Exception(body['message'] ?? 'Gagal memuat evaluasi');
    } on TimeoutException {
      debugPrint('EvaluasiView: timeout');
      rethrow;
    } catch (e) {
      debugPrint('EvaluasiView getEvaluasiList gagal: $e');
      rethrow;
    }
  }

  /// Ambil detail 1 evaluasi berdasarkan ID
  static Future<EvaluasiViewReport?> getEvaluasiDetail(int id) async {
    try {
      final token = await AuthService.getToken();
      final response = await http.get(
        Uri.parse('$_baseUrl/evaluasi_view.php?action=detail&id=$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        return EvaluasiViewReport.fromJson(body['data']);
      }
      return null;
    } catch (e) {
      debugPrint('EvaluasiView getDetail gagal: $e');
      return null;
    }
  }
}
