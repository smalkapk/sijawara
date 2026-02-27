import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

// ═══════════════════════════════════════
// Konstanta: Struktur item evaluasi
// ═══════════════════════════════════════

/// Opsi nilai evaluasi per item
const List<String> nilaiOptions = [
  'Sangat Baik',
  'Baik',
  'Cukup',
  'Perlu Perbaikan',
];

/// Kategori dan item evaluasi
class EvaluasiKategori {
  final String kode;
  final String label;
  final List<EvaluasiItem> items;

  const EvaluasiKategori({
    required this.kode,
    required this.label,
    required this.items,
  });
}

/// Tipe riwayat data yang bisa dilihat
enum RiwayatType { none, tugas, tahfidz, ibadah }

class EvaluasiItem {
  final String key;
  final String label;
  final RiwayatType riwayatType;

  const EvaluasiItem({
    required this.key,
    required this.label,
    this.riwayatType = RiwayatType.none,
  });
}

const List<EvaluasiKategori> evaluasiStruktur = [
  EvaluasiKategori(
    kode: 'A',
    label: 'KARAKTER',
    items: [
      EvaluasiItem(key: 'kedisiplinan', label: 'Kedisiplinan'),
      EvaluasiItem(key: 'kerjasama', label: 'Kerjasama/Kolaborasi'),
      EvaluasiItem(key: 'kemandirian', label: 'Kemandirian'),
      EvaluasiItem(key: 'kepedulian', label: 'Kepedulian'),
      EvaluasiItem(key: 'keberanian', label: 'Keberanian'),
      EvaluasiItem(key: 'tanggung_jawab', label: 'Tanggung Jawab'),
      EvaluasiItem(key: 'kepemimpinan', label: 'Kepemimpinan'),
    ],
  ),
  EvaluasiKategori(
    kode: 'B',
    label: 'KBM',
    items: [
      EvaluasiItem(key: 'keaktifan_di_kelas', label: 'Keaktifan di Kelas'),
      EvaluasiItem(key: 'adab_dengan_guru', label: 'Adab dengan Guru'),
      EvaluasiItem(key: 'adab_dengan_teman', label: 'Adab dengan Teman'),
      EvaluasiItem(
          key: 'tugas', label: 'Tugas', riwayatType: RiwayatType.tugas),
      EvaluasiItem(
          key: 'tahfidz_hafalan_doa',
          label: 'Tahfidz/Hafalan Doa',
          riwayatType: RiwayatType.tahfidz),
    ],
  ),
  EvaluasiKategori(
    kode: 'C',
    label: 'IBADAH',
    items: [
      EvaluasiItem(
          key: 'sholat_wajib',
          label: 'Sholat Wajib',
          riwayatType: RiwayatType.ibadah),
      EvaluasiItem(
          key: 'sholat_sunnah',
          label: 'Sholat Sunnah',
          riwayatType: RiwayatType.ibadah),
      EvaluasiItem(
          key: 'puasa', label: 'Puasa', riwayatType: RiwayatType.ibadah),
    ],
  ),
];

/// Nama bulan Indonesia
const List<String> bulanNames = [
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

/// Ordinal Indonesia (Pertama, Kedua, dst.)
String ordinalLabel(int n) {
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
  if (n > 0 && n < ordinals.length) return ordinals[n];
  return 'Ke-$n';
}

// ═══════════════════════════════════════
// Template teks evaluasi
// ═══════════════════════════════════════

/// Menghasilkan teks template berdasarkan item dan nilai pilihan.
/// Contoh: "Ananda telah menerapkan kedisiplinan dengan sangat baik"
String generateTemplateText(EvaluasiItem item, String nilai) {
  final lowerNilai = nilai.toLowerCase();
  final namaAspek = item.label.toLowerCase();

  switch (item.key) {
    // ── A. KARAKTER ──
    case 'kedisiplinan':
      return _templateKarakter('kedisiplinan', lowerNilai);
    case 'kerjasama':
      return _templateKarakter('kerjasama dan kolaborasi', lowerNilai);
    case 'kemandirian':
      return _templateKarakter('kemandirian', lowerNilai);
    case 'kepedulian':
      return _templateKarakter('kepedulian terhadap sesama', lowerNilai);
    case 'keberanian':
      return _templateKarakter('keberanian', lowerNilai);
    case 'tanggung_jawab':
      return _templateKarakter('tanggung jawab', lowerNilai);
    case 'kepemimpinan':
      return _templateKarakter('jiwa kepemimpinan', lowerNilai);

    // ── B. KBM ──
    case 'keaktifan_di_kelas':
      return _templateKBM('keaktifan di kelas', lowerNilai);
    case 'adab_dengan_guru':
      return _templateKBM('adab dengan guru', lowerNilai);
    case 'adab_dengan_teman':
      return _templateKBM('adab dengan teman', lowerNilai);
    case 'tugas':
      return _templateKBM('pengerjaan tugas', lowerNilai);
    case 'tahfidz_hafalan_doa':
      return _templateKBM('tahfidz dan hafalan doa', lowerNilai);

    // ── C. IBADAH ──
    case 'sholat_wajib':
      return _templateIbadah('pelaksanaan sholat wajib', lowerNilai);
    case 'sholat_sunnah':
      return _templateIbadah('pelaksanaan sholat sunnah', lowerNilai);
    case 'puasa':
      return _templateIbadah('pelaksanaan puasa', lowerNilai);

    default:
      return 'Ananda menunjukkan $namaAspek yang $lowerNilai.';
  }
}

String _templateKarakter(String aspek, String nilai) {
  switch (nilai) {
    case 'sangat baik':
      return 'Ananda telah menerapkan $aspek di dalam kelas dengan sangat baik. Pertahankan sikap positif ini.';
    case 'baik':
      return 'Ananda menunjukkan $aspek yang baik. Terus tingkatkan agar semakin konsisten.';
    case 'cukup':
      return 'Ananda perlu meningkatkan $aspek agar lebih konsisten dalam kegiatan sehari-hari.';
    case 'perlu perbaikan':
      return 'Ananda masih perlu bimbingan lebih dalam hal $aspek. Diperlukan perhatian khusus dari guru dan orang tua.';
    default:
      return '';
  }
}

String _templateKBM(String aspek, String nilai) {
  switch (nilai) {
    case 'sangat baik':
      return 'Ananda menunjukkan $aspek yang sangat baik selama proses belajar mengajar. Luar biasa!';
    case 'baik':
      return 'Ananda menunjukkan $aspek yang baik. Terus pertahankan semangat belajarnya.';
    case 'cukup':
      return 'Ananda perlu meningkatkan $aspek agar hasil belajar lebih optimal.';
    case 'perlu perbaikan':
      return 'Ananda masih perlu meningkatkan $aspek secara signifikan. Bimbingan tambahan sangat disarankan.';
    default:
      return '';
  }
}

String _templateIbadah(String aspek, String nilai) {
  switch (nilai) {
    case 'sangat baik':
      return 'Ananda sangat konsisten dalam $aspek. Semoga menjadi kebiasaan yang terus istiqomah.';
    case 'baik':
      return 'Ananda menunjukkan $aspek yang baik. Terus jaga konsistensinya.';
    case 'cukup':
      return 'Ananda perlu lebih konsisten dalam $aspek. Motivasi dari lingkungan sangat membantu.';
    case 'perlu perbaikan':
      return 'Ananda masih perlu perbaikan dalam $aspek. Diperlukan pendampingan dari orang tua dan guru.';
    default:
      return '';
  }
}

/// Label riwayat berdasarkan tipe
String riwayatLabel(RiwayatType type) {
  switch (type) {
    case RiwayatType.tugas:
      return 'Tugas';
    case RiwayatType.tahfidz:
      return 'Tahfidz';
    case RiwayatType.ibadah:
      return 'Ibadah';
    default:
      return '';
  }
}

// ═══════════════════════════════════════
// Model: Laporan Evaluasi
// ═══════════════════════════════════════

class GuruEvaluasiReport {
  final String id;
  final int evaluasiNumber;
  final String bulan;
  final Map<String, String> nilaiData;
  final Map<String, String> keteranganData;
  final String catatan;
  final DateTime evaluasiDate;
  final DateTime createdAt;

  GuruEvaluasiReport({
    required this.id,
    this.evaluasiNumber = 1,
    required this.bulan,
    required this.nilaiData,
    Map<String, String>? keteranganData,
    this.catatan = '',
    required this.evaluasiDate,
    DateTime? createdAt,
  })  : keteranganData = keteranganData ?? {},
        createdAt = createdAt ?? DateTime.now();

  String get title => 'Laporan Evaluasi ${ordinalLabel(evaluasiNumber)}';

  factory GuruEvaluasiReport.fromJson(Map<String, dynamic> json) {
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

    return GuruEvaluasiReport(
      id: json['id']?.toString() ?? '',
      evaluasiNumber: json['evaluasi_number'] is int
          ? json['evaluasi_number']
          : int.tryParse(json['evaluasi_number']?.toString() ?? '1') ?? 1,
      bulan: json['bulan'] as String? ?? '',
      nilaiData: nilai,
      keteranganData: keterangan,
      catatan: json['catatan'] as String? ?? '',
      evaluasiDate: DateTime.parse(json['evaluasi_date'] as String),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'evaluasi_number': evaluasiNumber,
        'bulan': bulan,
        'nilai_data': jsonEncode(nilaiData),
        'keterangan_data': jsonEncode(keteranganData),
        'catatan': catatan,
        'evaluasi_date': evaluasiDate.toIso8601String().substring(0, 10),
        'created_at': createdAt.toIso8601String(),
      };
}

// ═══════════════════════════════════════
// Model: Riwayat data bulanan untuk bottom sheet
// ═══════════════════════════════════════

class RiwayatItem {
  final String title;
  final String subtitle;
  final String date;
  final String? badge;

  RiwayatItem({
    required this.title,
    this.subtitle = '',
    required this.date,
    this.badge,
  });
}

// ═══════════════════════════════════════
// Service
// ═══════════════════════════════════════

class GuruEvaluasiService {
  static const String _baseUrl = 'https://portal-smalka.com/api';
  static const String _reportsCachePrefix = 'guru_evaluasi_reports_';

  // GET: Ambil laporan evaluasi per siswa
  static Future<List<GuruEvaluasiReport>> getReports({
    required int studentId,
  }) async {
    try {
      final token = await AuthService.getToken();
      final uri = Uri.parse(
        '$_baseUrl/guru_evaluasi.php?action=reports&student_id=$studentId',
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
            dataList.map((e) => GuruEvaluasiReport.fromJson(e)).toList();
        reports.sort((a, b) => a.evaluasiNumber.compareTo(b.evaluasiNumber));

        await _saveReportsToCache(studentId, reports);
        return reports;
      }
    } on TimeoutException {
      debugPrint('GuruEvaluasi: timeout reports, pakai cache lokal');
    } catch (e) {
      debugPrint('GuruEvaluasi: gagal fetch reports ($e), pakai cache lokal');
    }

    return _getReportsFromCache(studentId);
  }

  // POST: Simpan laporan evaluasi baru
  static Future<String?> addReport({
    required int studentId,
    required GuruEvaluasiReport report,
  }) async {
    try {
      final token = await AuthService.getToken();
      final response = await http.post(
        Uri.parse('$_baseUrl/guru_evaluasi.php'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'student_id': studentId,
          'bulan': report.bulan,
          'nilai_data': report.nilaiData,
          'keterangan_data': report.keteranganData,
          'catatan': report.catatan,
          'evaluasi_date':
              report.evaluasiDate.toIso8601String().substring(0, 10),
        }),
      ).timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && body['success'] == true) {
        return body['data']?['id']?.toString();
      }
      throw Exception(body['message'] ?? 'Gagal menyimpan');
    } catch (e) {
      debugPrint('GuruEvaluasi addReport gagal: $e');
      rethrow;
    }
  }

  // POST: Update laporan evaluasi
  static Future<void> updateReport({
    required int studentId,
    required GuruEvaluasiReport report,
  }) async {
    try {
      final token = await AuthService.getToken();
      final response = await http.post(
        Uri.parse('$_baseUrl/guru_evaluasi.php'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'id': report.id,
          'student_id': studentId,
          'bulan': report.bulan,
          'nilai_data': report.nilaiData,
          'keterangan_data': report.keteranganData,
          'catatan': report.catatan,
          'evaluasi_date':
              report.evaluasiDate.toIso8601String().substring(0, 10),
        }),
      ).timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && body['success'] == true) {
        return;
      }
      throw Exception(body['message'] ?? 'Gagal memperbarui');
    } catch (e) {
      debugPrint('GuruEvaluasi updateReport gagal: $e');
      rethrow;
    }
  }

  // DELETE: Hapus laporan evaluasi
  static Future<void> deleteReport(String id) async {
    try {
      final token = await AuthService.getToken();
      final response = await http.delete(
        Uri.parse('$_baseUrl/guru_evaluasi.php?id=$id'),
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
      debugPrint('GuruEvaluasi deleteReport gagal: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════
  // GET: Riwayat data bulanan (tugas / tahfidz / ibadah)
  // ═══════════════════════════════════════
  static Future<List<RiwayatItem>> getRiwayat({
    required int studentId,
    required RiwayatType type,
    required String month, // format: YYYY-MM
  }) async {
    try {
      final token = await AuthService.getToken();
      final typeStr = type.name; // tugas, tahfidz, ibadah
      final uri = Uri.parse(
        '$_baseUrl/guru_evaluasi.php?action=riwayat&student_id=$studentId&type=$typeStr&month=$month',
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
        return dataList.map((e) {
          final m = e as Map<String, dynamic>;
          return RiwayatItem(
            title: m['title']?.toString() ?? '',
            subtitle: m['subtitle']?.toString() ?? '',
            date: m['date']?.toString() ?? '',
            badge: m['badge']?.toString(),
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('GuruEvaluasi getRiwayat gagal: $e');
    }
    return [];
  }

  // ── Cache helpers ──
  static String _reportsCacheKey(int studentId) =>
      '${_reportsCachePrefix}$studentId';

  static Future<List<GuruEvaluasiReport>> _getReportsFromCache(
      int studentId) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_reportsCacheKey(studentId));
    if (jsonStr == null || jsonStr.isEmpty) return [];

    final List<dynamic> jsonList = jsonDecode(jsonStr);
    final reports =
        jsonList.map((e) => GuruEvaluasiReport.fromJson(e)).toList();
    reports.sort((a, b) => a.evaluasiNumber.compareTo(b.evaluasiNumber));
    return reports;
  }

  static Future<void> _saveReportsToCache(
      int studentId, List<GuruEvaluasiReport> reports) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(reports.map((r) => r.toJson()).toList());
    await prefs.setString(_reportsCacheKey(studentId), jsonStr);
  }
}
