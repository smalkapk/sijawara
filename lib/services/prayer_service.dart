import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

/// Service untuk komunikasi dengan API prayer_log & student_data.
class PrayerService {
  static const String _baseUrl = 'https://portal-smalka.com/api';

  // ═══════════════════════════════════════
  // GET: Ambil rekap shalat per tanggal
  // ═══════════════════════════════════════
  static Future<PrayerDayData> getPrayersByDate(String date) async {
    final token = await AuthService.getToken();
    final uri = Uri.parse('$_baseUrl/prayer_log.php?date=$date');

    try {
      final response = await http.get(uri, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      }).timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        return PrayerDayData.fromJson(body['data']);
      } else {
        throw PrayerServiceException(
          body['message'] ?? 'Gagal mengambil data shalat',
        );
      }
    } on TimeoutException {
      throw PrayerServiceException('Koneksi timeout, coba lagi');
    } on http.ClientException {
      throw PrayerServiceException('Tidak dapat terhubung ke server');
    } on FormatException {
      throw PrayerServiceException('Response server tidak valid');
    } catch (e) {
      throw PrayerServiceException('Terjadi kesalahan: $e');
    }
  }

  // ═══════════════════════════════════════
  // GET: Ambil summary shalat sebulan
  // ═══════════════════════════════════════
  static Future<PrayerMonthData> getPrayersByMonth(String month) async {
    final token = await AuthService.getToken();
    final uri = Uri.parse('$_baseUrl/prayer_log.php?month=$month');

    try {
      final response = await http.get(uri, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      }).timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        return PrayerMonthData.fromJson(body['data']);
      } else {
        throw PrayerServiceException(
          body['message'] ?? 'Gagal mengambil data bulanan',
        );
      }
    } on TimeoutException {
      throw PrayerServiceException('Koneksi timeout, coba lagi');
    } on http.ClientException {
      throw PrayerServiceException('Tidak dapat terhubung ke server');
    } catch (e) {
      throw PrayerServiceException('Terjadi kesalahan: $e');
    }
  }

  // ═══════════════════════════════════════
  // POST: Simpan rekap shalat + lokasi GPS
  // ═══════════════════════════════════════
  static Future<PrayerSaveResult> savePrayers({
    required String date,
    required Map<String, PrayerEntry> prayers,
    String? wakeUpTime,
    List<String>? deeds,
  }) async {
    final token = await AuthService.getToken();
    final uri = Uri.parse('$_baseUrl/prayer_log.php');

    // Convert PrayerEntry map ke JSON-friendly map
    final prayersJson = <String, dynamic>{};
    prayers.forEach((name, entry) {
      prayersJson[name] = entry.toJson();
    });

    try {
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'date': date,
          'prayers': prayersJson,
          'wake_up_time': wakeUpTime,
          'deeds': deeds ?? [],
        }),
      ).timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        return PrayerSaveResult.fromJson(body['data']);
      } else {
        throw PrayerServiceException(
          body['message'] ?? 'Gagal menyimpan rekap shalat',
        );
      }
    } on TimeoutException {
      throw PrayerServiceException('Koneksi timeout, coba lagi');
    } on http.ClientException {
      throw PrayerServiceException('Tidak dapat terhubung ke server');
    } catch (e) {
      throw PrayerServiceException('Terjadi kesalahan: $e');
    }
  }

  // ═══════════════════════════════════════
  // GET: Ambil data student (poin, streak, badges)
  // ═══════════════════════════════════════
  static Future<StudentData> getStudentData() async {
    final token = await AuthService.getToken();
    final uri = Uri.parse('$_baseUrl/student_data.php');

    try {
      final response = await http.get(uri, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      }).timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        return StudentData.fromJson(body['data']);
      } else {
        throw PrayerServiceException(
          body['message'] ?? 'Gagal mengambil data siswa',
        );
      }
    } on TimeoutException {
      throw PrayerServiceException('Koneksi timeout, coba lagi');
    } on http.ClientException {
      throw PrayerServiceException('Tidak dapat terhubung ke server');
    } catch (e) {
      throw PrayerServiceException('Terjadi kesalahan: $e');
    }
  }

  // ═══════════════════════════════════════
  // GET: Rincian poin (breakdown)
  // ═══════════════════════════════════════
  static Future<PointsBreakdown> getPointsBreakdown() async {
    final token = await AuthService.getToken();
    final uri = Uri.parse('$_baseUrl/points_breakdown.php');

    try {
      final response = await http.get(uri, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      }).timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        return PointsBreakdown.fromJson(body['data']);
      } else {
        throw PrayerServiceException(
          body['message'] ?? 'Gagal mengambil rincian poin',
        );
      }
    } on TimeoutException {
      throw PrayerServiceException('Koneksi timeout, coba lagi');
    } on http.ClientException {
      throw PrayerServiceException('Tidak dapat terhubung ke server');
    } catch (e) {
      throw PrayerServiceException('Terjadi kesalahan: $e');
    }
  }
}

// ═══════════════════════════════════════
// Data Models
// ═══════════════════════════════════════

/// Entry shalat tunggal untuk dikirim ke server
class PrayerEntry {
  final String status; // 'done', 'done_jamaah', 'missed'
  final double? latitude;
  final double? longitude;
  final String? locationName;

  const PrayerEntry({
    required this.status,
    this.latitude,
    this.longitude,
    this.locationName,
  });

  Map<String, dynamic> toJson() => {
        'status': status,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (locationName != null) 'location_name': locationName,
      };
}

/// Data shalat satu hari dari server
class PrayerDayData {
  final String date;
  final Map<String, PrayerLogEntry> prayers;
  final int totalPoints;
  final int streak;
  final String? wakeUpTime;
  final List<String> deeds;

  PrayerDayData({
    required this.date,
    required this.prayers,
    required this.totalPoints,
    required this.streak,
    this.wakeUpTime,
    this.deeds = const [],
  });

  factory PrayerDayData.fromJson(Map<String, dynamic> json) {
    final rawPrayers = json['prayers'] as Map<String, dynamic>? ?? {};
    final prayers = <String, PrayerLogEntry>{};
    rawPrayers.forEach((name, data) {
      prayers[name] = PrayerLogEntry.fromJson(data as Map<String, dynamic>);
    });

    final rawDeeds = json['deeds'];
    final deeds = <String>[];
    if (rawDeeds is List) {
      for (final d in rawDeeds) {
        deeds.add(d.toString());
      }
    }

    return PrayerDayData(
      date: json['date'] ?? '',
      prayers: prayers,
      totalPoints: json['total_points'] ?? 0,
      streak: json['streak'] ?? 0,
      wakeUpTime: json['wake_up_time'],
      deeds: deeds,
    );
  }
}

/// Entry shalat dari server (sudah disimpan)
class PrayerLogEntry {
  final String status;
  final int points;
  final double? latitude;
  final double? longitude;
  final String? locationName;

  PrayerLogEntry({
    required this.status,
    required this.points,
    this.latitude,
    this.longitude,
    this.locationName,
  });

  factory PrayerLogEntry.fromJson(Map<String, dynamic> json) {
    return PrayerLogEntry(
      status: json['status'] ?? 'missed',
      points: json['points'] ?? 0,
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
      locationName: json['location_name'],
    );
  }
}

/// Summary bulanan
class PrayerMonthData {
  final String month;
  final Map<String, int> dailyCounts; // date -> done count
  final int totalPoints;
  final int streak;

  PrayerMonthData({
    required this.month,
    required this.dailyCounts,
    required this.totalPoints,
    required this.streak,
  });

  factory PrayerMonthData.fromJson(Map<String, dynamic> json) {
    final raw = json['daily_counts'] as Map<String, dynamic>? ?? {};
    final counts = <String, int>{};
    raw.forEach((k, v) => counts[k] = v is int ? v : int.tryParse('$v') ?? 0);

    return PrayerMonthData(
      month: json['month'] ?? '',
      dailyCounts: counts,
      totalPoints: json['total_points'] ?? 0,
      streak: json['streak'] ?? 0,
    );
  }
}

/// Hasil simpan shalat
class PrayerSaveResult {
  final String date;
  final int doneCount;
  final int earnedPoints;
  final int bonusPoints;
  final int wakeUpPoints;
  final int deedsPoints;
  final int comboBonus;
  final int totalPoints;
  final int streak;

  PrayerSaveResult({
    required this.date,
    required this.doneCount,
    required this.earnedPoints,
    this.bonusPoints = 0,
    this.wakeUpPoints = 0,
    this.deedsPoints = 0,
    this.comboBonus = 0,
    required this.totalPoints,
    required this.streak,
  });

  factory PrayerSaveResult.fromJson(Map<String, dynamic> json) {
    return PrayerSaveResult(
      date: json['date'] ?? '',
      doneCount: json['done_count'] ?? 0,
      earnedPoints: json['earned_points'] ?? 0,
      bonusPoints: json['bonus_points'] ?? 0,
      wakeUpPoints: json['wake_up_points'] ?? 0,
      deedsPoints: json['deeds_points'] ?? 0,
      comboBonus: json['combo_bonus'] ?? 0,
      totalPoints: json['total_points'] ?? 0,
      streak: json['streak'] ?? 0,
    );
  }
}

/// Data student lengkap
class StudentData {
  final int studentId;
  final String name;
  final String? email;
  final String? avatarUrl;
  final String? className;
  final int totalPoints;
  final int currentLevel;
  final int streak;
  final String? lastActiveDate;
  final int doneToday;
  final List<Map<String, dynamic>> badges;

  StudentData({
    required this.studentId,
    required this.name,
    this.email,
    this.avatarUrl,
    this.className,
    required this.totalPoints,
    required this.currentLevel,
    required this.streak,
    this.lastActiveDate,
    required this.doneToday,
    required this.badges,
  });

  factory StudentData.fromJson(Map<String, dynamic> json) {
    return StudentData(
      studentId: json['student_id'] ?? 0,
      name: json['name'] ?? '',
      email: json['email'],
      avatarUrl: json['avatar_url'],
      className: json['class_name'],
      totalPoints: json['total_points'] ?? 0,
      currentLevel: json['current_level'] ?? 1,
      streak: json['streak'] ?? 0,
      lastActiveDate: json['last_active_date'],
      doneToday: json['done_today'] ?? 0,
      badges: (json['badges'] as List<dynamic>?)
              ?.map((b) => b as Map<String, dynamic>)
              .toList() ??
          [],
    );
  }
}

/// Exception khusus PrayerService
class PrayerServiceException implements Exception {
  final String message;
  PrayerServiceException(this.message);

  @override
  String toString() => message;
}

/// Rincian poin per kategori
class PointsBreakdownItem {
  final int points;
  final int count;
  final int perItem;

  PointsBreakdownItem({
    required this.points,
    required this.count,
    required this.perItem,
  });

  factory PointsBreakdownItem.fromJson(Map<String, dynamic> json) {
    return PointsBreakdownItem(
      points: json['points'] ?? 0,
      count: json['count'] ?? 0,
      perItem: json['per_item'] ?? 0,
    );
  }
}

/// Breakdown total poin siswa
class PointsBreakdown {
  final int totalPoints;
  final int streak;
  final PointsBreakdownItem shalatSendiri;
  final PointsBreakdownItem shalatJamaah;
  final PointsBreakdownItem bonus5of5;
  final PointsBreakdownItem bangunPagi;
  final PointsBreakdownItem kebaikan;
  final PointsBreakdownItem comboBonus;
  final PointsBreakdownItem publicSpeaking;
  final PointsBreakdownItem diskusi;

  PointsBreakdown({
    required this.totalPoints,
    required this.streak,
    required this.shalatSendiri,
    required this.shalatJamaah,
    required this.bonus5of5,
    required this.bangunPagi,
    required this.kebaikan,
    required this.comboBonus,
    required this.publicSpeaking,
    required this.diskusi,
  });

  factory PointsBreakdown.fromJson(Map<String, dynamic> json) {
    final b = json['breakdown'] as Map<String, dynamic>? ?? {};
    return PointsBreakdown(
      totalPoints: json['total_points'] ?? 0,
      streak: json['streak'] ?? 0,
      shalatSendiri: PointsBreakdownItem.fromJson(
          b['shalat_sendiri'] as Map<String, dynamic>? ?? {}),
      shalatJamaah: PointsBreakdownItem.fromJson(
          b['shalat_jamaah'] as Map<String, dynamic>? ?? {}),
      bonus5of5: PointsBreakdownItem.fromJson(
          b['bonus_5_5'] as Map<String, dynamic>? ?? {}),
      bangunPagi: PointsBreakdownItem.fromJson(
          b['bangun_pagi'] as Map<String, dynamic>? ?? {}),
      kebaikan: PointsBreakdownItem.fromJson(
          b['kebaikan'] as Map<String, dynamic>? ?? {}),
      comboBonus: PointsBreakdownItem.fromJson(
          b['combo_bonus'] as Map<String, dynamic>? ?? {}),
      publicSpeaking: PointsBreakdownItem.fromJson(
          b['public_speaking'] as Map<String, dynamic>? ?? {}),
      diskusi: PointsBreakdownItem.fromJson(
          b['diskusi'] as Map<String, dynamic>? ?? {}),
    );
  }
}
