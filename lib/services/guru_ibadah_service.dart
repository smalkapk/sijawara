import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

// ═══════════════════════════════════════
// Model: Siswa (untuk daftar siswa guru)
// ═══════════════════════════════════════

class GuruIbadahStudent {
  final int studentId;
  final String nis;
  final String name;
  final String className;

  GuruIbadahStudent({
    required this.studentId,
    required this.nis,
    required this.name,
    required this.className,
  });

  factory GuruIbadahStudent.fromJson(Map<String, dynamic> json) {
    return GuruIbadahStudent(
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
// Model: Summary bulanan
// ═══════════════════════════════════════

class GuruIbadahMonthData {
  final String month;
  final Map<String, int> dailyCounts; // date -> done count

  GuruIbadahMonthData({
    required this.month,
    required this.dailyCounts,
  });

  factory GuruIbadahMonthData.fromJson(Map<String, dynamic> json) {
    final raw = json['daily_counts'] as Map<String, dynamic>? ?? {};
    final counts = <String, int>{};
    raw.forEach((k, v) => counts[k] = v is int ? v : int.tryParse('$v') ?? 0);

    return GuruIbadahMonthData(
      month: json['month'] ?? '',
      dailyCounts: counts,
    );
  }
}

// ═══════════════════════════════════════
// Model: Detail ibadah per hari
// ═══════════════════════════════════════

class GuruIbadahDayData {
  final String date;
  final Map<String, GuruIbadahPrayerEntry> prayers;
  final String? wakeUpTime;
  final List<String> deeds;

  GuruIbadahDayData({
    required this.date,
    required this.prayers,
    this.wakeUpTime,
    this.deeds = const [],
  });

  factory GuruIbadahDayData.fromJson(Map<String, dynamic> json) {
    final rawPrayers = json['prayers'] as Map<String, dynamic>? ?? {};
    final prayers = <String, GuruIbadahPrayerEntry>{};
    rawPrayers.forEach((name, data) {
      prayers[name] =
          GuruIbadahPrayerEntry.fromJson(data as Map<String, dynamic>);
    });

    final rawDeeds = json['deeds'];
    final deeds = <String>[];
    if (rawDeeds is List) {
      for (final d in rawDeeds) {
        deeds.add(d.toString());
      }
    }

    return GuruIbadahDayData(
      date: json['date'] ?? '',
      prayers: prayers,
      wakeUpTime: json['wake_up_time'],
      deeds: deeds,
    );
  }
}

class GuruIbadahPrayerEntry {
  final String status; // 'done', 'done_jamaah', 'missed'
  final int points;
  final double? latitude;
  final double? longitude;
  final String? locationName;

  GuruIbadahPrayerEntry({
    required this.status,
    required this.points,
    this.latitude,
    this.longitude,
    this.locationName,
  });

  factory GuruIbadahPrayerEntry.fromJson(Map<String, dynamic> json) {
    return GuruIbadahPrayerEntry(
      status: json['status'] ?? 'missed',
      points: json['points'] ?? 0,
      latitude: json['latitude'] != null
          ? (json['latitude'] as num).toDouble()
          : null,
      longitude: json['longitude'] != null
          ? (json['longitude'] as num).toDouble()
          : null,
      locationName: json['location_name'],
    );
  }
}

// ═══════════════════════════════════════
// Service
// ═══════════════════════════════════════

class GuruIbadahService {
  static const String _baseUrl = 'https://portal-smalka.com/api';

  /// GET: Ambil daftar siswa yang diajar guru
  static Future<List<GuruIbadahStudent>> getStudents() async {
    try {
      final token = await AuthService.getToken();
      final uri = Uri.parse('$_baseUrl/guru_ibadah.php?action=students');
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
        return dataList.map((e) => GuruIbadahStudent.fromJson(e)).toList();
      }
      throw Exception(body['message'] ?? 'Gagal mengambil daftar siswa');
    } on TimeoutException {
      debugPrint('GuruIbadah: timeout getStudents');
      rethrow;
    } catch (e) {
      debugPrint('GuruIbadah: gagal fetch students ($e)');
      rethrow;
    }
  }

  /// GET: Ambil summary ibadah bulanan siswa
  static Future<GuruIbadahMonthData> getMonthData({
    required int studentId,
    required String month, // YYYY-MM
  }) async {
    try {
      final token = await AuthService.getToken();
      final uri = Uri.parse(
        '$_baseUrl/guru_ibadah.php?action=month&student_id=$studentId&month=$month',
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
        return GuruIbadahMonthData.fromJson(body['data']);
      }
      throw Exception(body['message'] ?? 'Gagal mengambil data bulanan');
    } on TimeoutException {
      debugPrint('GuruIbadah: timeout getMonthData');
      rethrow;
    } catch (e) {
      debugPrint('GuruIbadah: gagal fetch month data ($e)');
      rethrow;
    }
  }

  /// GET: Ambil detail ibadah per hari siswa
  static Future<GuruIbadahDayData> getDayData({
    required int studentId,
    required String date, // YYYY-MM-DD
  }) async {
    try {
      final token = await AuthService.getToken();
      final uri = Uri.parse(
        '$_baseUrl/guru_ibadah.php?action=day&student_id=$studentId&date=$date',
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
        return GuruIbadahDayData.fromJson(body['data']);
      }
      throw Exception(body['message'] ?? 'Gagal mengambil data ibadah');
    } on TimeoutException {
      debugPrint('GuruIbadah: timeout getDayData');
      rethrow;
    } catch (e) {
      debugPrint('GuruIbadah: gagal fetch day data ($e)');
      rethrow;
    }
  }

  /// POST: Guru update ibadah siswa
  static Future<Map<String, dynamic>> updatePrayers({
    required int studentId,
    required String date,
    required Map<String, String> prayers, // prayer_name -> status
  }) async {
    try {
      final token = await AuthService.getToken();
      final prayersJson = <String, dynamic>{};
      prayers.forEach((name, status) {
        prayersJson[name] = {'status': status};
      });

      final response = await http.post(
        Uri.parse('$_baseUrl/guru_ibadah.php'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'student_id': studentId,
          'date': date,
          'prayers': prayersJson,
        }),
      ).timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && body['success'] == true) {
        return body['data'] as Map<String, dynamic>? ?? {};
      }
      throw Exception(body['message'] ?? 'Gagal menyimpan');
    } catch (e) {
      debugPrint('GuruIbadah updatePrayers gagal: $e');
      rethrow;
    }
  }
}
