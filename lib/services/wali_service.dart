import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

/// Service untuk komunikasi dengan API wali dashboard.
class WaliService {
  static const String _baseUrl = 'https://portal-smalka.com/api';

  // ═══════════════════════════════════════
  // GET: Ambil data dashboard wali
  // ═══════════════════════════════════════
  static Future<WaliDashboardData> getDashboard({int? studentId}) async {
    final token = await AuthService.getToken();
    String url = '$_baseUrl/wali_dashboard.php';
    if (studentId != null) {
      url += '?student_id=$studentId';
    }
    final uri = Uri.parse(url);

    try {
      final response = await http.get(uri, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      }).timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        return WaliDashboardData.fromJson(body['data']);
      } else {
        throw WaliServiceException(
          body['message'] ?? 'Gagal mengambil data dashboard',
        );
      }
    } on TimeoutException {
      throw WaliServiceException('Koneksi timeout, coba lagi');
    } on http.ClientException {
      throw WaliServiceException('Tidak dapat terhubung ke server');
    } on FormatException {
      throw WaliServiceException('Response server tidak valid');
    } catch (e) {
      if (e is WaliServiceException) rethrow;
      throw WaliServiceException('Terjadi kesalahan: $e');
    }
  }

  // ═══════════════════════════════════════
  // GET: Ambil data heatmap kalender bulanan
  // ═══════════════════════════════════════
  static Future<WaliMonthlyCalendarData> getMonthlyCalendar({
    required int studentId,
    String? month, // format YYYY-MM
  }) async {
    final token = await AuthService.getToken();
    String url = '$_baseUrl/wali_monthly_calendar.php?student_id=$studentId';
    if (month != null) {
      url += '&month=$month';
    }
    final uri = Uri.parse(url);

    try {
      final response = await http.get(uri, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      }).timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        return WaliMonthlyCalendarData.fromJson(body['data']);
      } else {
        throw WaliServiceException(
          body['message'] ?? 'Gagal mengambil data kalender',
        );
      }
    } on TimeoutException {
      throw WaliServiceException('Koneksi timeout, coba lagi');
    } on http.ClientException {
      throw WaliServiceException('Tidak dapat terhubung ke server');
    } on FormatException {
      throw WaliServiceException('Response server tidak valid');
    } catch (e) {
      if (e is WaliServiceException) rethrow;
      throw WaliServiceException('Terjadi kesalahan: $e');
    }
  }

  // ═══════════════════════════════════════
  // GET: Ambil live timeline siswa
  // ═══════════════════════════════════════
  static Future<WaliLiveTimelineData> getLiveTimeline({
    int? studentId,
    String? date, // format YYYY-MM-DD
  }) async {
    final token = await AuthService.getToken();
    String url = '$_baseUrl/wali_live_timeline.php';
    final params = <String>[];
    if (studentId != null) params.add('student_id=$studentId');
    if (date != null) params.add('date=$date');
    if (params.isNotEmpty) url += '?${params.join('&')}';
    final uri = Uri.parse(url);

    try {
      final response = await http.get(uri, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      }).timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        return WaliLiveTimelineData.fromJson(body['data']);
      } else {
        throw WaliServiceException(
          body['message'] ?? 'Gagal mengambil data timeline',
        );
      }
    } on TimeoutException {
      throw WaliServiceException('Koneksi timeout, coba lagi');
    } on http.ClientException {
      throw WaliServiceException('Tidak dapat terhubung ke server');
    } on FormatException {
      throw WaliServiceException('Response server tidak valid');
    } catch (e) {
      if (e is WaliServiceException) rethrow;
      throw WaliServiceException('Terjadi kesalahan: $e');
    }
  }

  // ═══════════════════════════════════════
  // GET: Ambil daftar anak yang ditautkan (Pusat Akun)
  // ═══════════════════════════════════════
  static Future<WaliAccountCenterData> getLinkedStudents() async {
    final token = await AuthService.getToken();
    final uri = Uri.parse('$_baseUrl/wali_account_center.php');

    try {
      final response = await http.get(uri, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      }).timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        return WaliAccountCenterData.fromJson(body['data']);
      } else {
        throw WaliServiceException(
          body['message'] ?? 'Gagal mengambil data akun',
        );
      }
    } on TimeoutException {
      throw WaliServiceException('Koneksi timeout, coba lagi');
    } on http.ClientException {
      throw WaliServiceException('Tidak dapat terhubung ke server');
    } on FormatException {
      throw WaliServiceException('Response server tidak valid');
    } catch (e) {
      if (e is WaliServiceException) rethrow;
      throw WaliServiceException('Terjadi kesalahan: $e');
    }
  }

  // ═══════════════════════════════════════
  // POST: Tambah siswa via login akun siswa
  // ═══════════════════════════════════════
  static Future<WaliLinkedStudent> addStudent({
    required String email,
    required String password,
    required String relationship,
  }) async {
    final token = await AuthService.getToken();
    final uri = Uri.parse('$_baseUrl/wali_account_center.php');

    try {
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'email': email,
          'password': password,
          'relationship': relationship,
        }),
      ).timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        return WaliLinkedStudent.fromJson(body['data']);
      } else {
        throw WaliServiceException(
          body['message'] ?? 'Gagal menambahkan siswa',
        );
      }
    } on TimeoutException {
      throw WaliServiceException('Koneksi timeout, coba lagi');
    } on http.ClientException {
      throw WaliServiceException('Tidak dapat terhubung ke server');
    } on FormatException {
      throw WaliServiceException('Response server tidak valid');
    } catch (e) {
      if (e is WaliServiceException) rethrow;
      throw WaliServiceException('Terjadi kesalahan: $e');
    }
  }

  // ═══════════════════════════════════════
  // DELETE: Hapus relasi parent-student
  // ═══════════════════════════════════════
  static Future<void> removeStudent({required int relationId}) async {
    final token = await AuthService.getToken();
    final uri = Uri.parse('$_baseUrl/wali_account_center.php');

    try {
      final response = await http.delete(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'relation_id': relationId}),
      ).timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        return;
      } else {
        throw WaliServiceException(
          body['message'] ?? 'Gagal menghapus relasi',
        );
      }
    } on TimeoutException {
      throw WaliServiceException('Koneksi timeout, coba lagi');
    } on http.ClientException {
      throw WaliServiceException('Tidak dapat terhubung ke server');
    } on FormatException {
      throw WaliServiceException('Response server tidak valid');
    } catch (e) {
      if (e is WaliServiceException) rethrow;
      throw WaliServiceException('Terjadi kesalahan: $e');
    }
  }

  // ═══════════════════════════════════════
  // GET: Ambil detail satu hari
  // ═══════════════════════════════════════
  static Future<WaliDayDetailData> getDayDetail({
    required int studentId,
    required String date, // format YYYY-MM-DD
  }) async {
    final token = await AuthService.getToken();
    final url =
        '$_baseUrl/wali_monthly_calendar.php?student_id=$studentId&day_detail=$date';
    final uri = Uri.parse(url);

    try {
      final response = await http.get(uri, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      }).timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        return WaliDayDetailData.fromJson(body['data']);
      } else {
        throw WaliServiceException(
          body['message'] ?? 'Gagal mengambil detail hari',
        );
      }
    } on TimeoutException {
      throw WaliServiceException('Koneksi timeout, coba lagi');
    } on http.ClientException {
      throw WaliServiceException('Tidak dapat terhubung ke server');
    } on FormatException {
      throw WaliServiceException('Response server tidak valid');
    } catch (e) {
      if (e is WaliServiceException) rethrow;
      throw WaliServiceException('Terjadi kesalahan: $e');
    }
  }

  // ═══════════════════════════════════════
  // GET: Ambil profil wali saat ini
  // ═══════════════════════════════════════
  static Future<WaliParentInfo> getWaliProfile() async {
    final token = await AuthService.getToken();
    final uri = Uri.parse('$_baseUrl/wali_update_profile.php');

    try {
      final response = await http.get(uri, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      }).timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        return WaliParentInfo.fromJson(body['data']);
      } else {
        throw WaliServiceException(
          body['message'] ?? 'Gagal mengambil data profil',
        );
      }
    } on TimeoutException {
      throw WaliServiceException('Koneksi timeout, coba lagi');
    } on http.ClientException {
      throw WaliServiceException('Tidak dapat terhubung ke server');
    } on FormatException {
      throw WaliServiceException('Response server tidak valid');
    } catch (e) {
      if (e is WaliServiceException) rethrow;
      throw WaliServiceException('Terjadi kesalahan: $e');
    }
  }

  // ═══════════════════════════════════════
  // POST: Update profil wali (nama, phone, alamat)
  // ═══════════════════════════════════════
  static Future<WaliParentInfo> updateWaliProfile({
    required String name,
    String? phone,
    String? address,
    double? addressLat,
    double? addressLng,
  }) async {
    final token = await AuthService.getToken();
    final uri = Uri.parse('$_baseUrl/wali_update_profile.php');

    try {
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'name': name,
          'phone': phone ?? '',
          'address': address ?? '',
          'address_lat': addressLat,
          'address_lng': addressLng,
        }),
      ).timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        return WaliParentInfo.fromJson(body['data']);
      } else {
        throw WaliServiceException(
          body['message'] ?? 'Gagal memperbarui profil',
        );
      }
    } on TimeoutException {
      throw WaliServiceException('Koneksi timeout, coba lagi');
    } on http.ClientException {
      throw WaliServiceException('Tidak dapat terhubung ke server');
    } on FormatException {
      throw WaliServiceException('Response server tidak valid');
    } catch (e) {
      if (e is WaliServiceException) rethrow;
      throw WaliServiceException('Terjadi kesalahan: $e');
    }
  }

  // ═══════════════════════════════════════
  // POST: Upload avatar wali
  // ═══════════════════════════════════════
  static Future<String> uploadWaliAvatar(File imageFile) async {
    final token = await AuthService.getToken();
    final uri = Uri.parse('$_baseUrl/wali_update_profile.php');

    try {
      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(
        await http.MultipartFile.fromPath('avatar', imageFile.path),
      );

      final streamResponse = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamResponse);
      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        return body['data']['avatar_url'] ?? '';
      } else {
        throw WaliServiceException(
          body['message'] ?? 'Gagal mengupload foto',
        );
      }
    } on TimeoutException {
      throw WaliServiceException('Koneksi timeout, coba lagi');
    } on http.ClientException {
      throw WaliServiceException('Tidak dapat terhubung ke server');
    } catch (e) {
      if (e is WaliServiceException) rethrow;
      throw WaliServiceException('Terjadi kesalahan: $e');
    }
  }

  // POST: Set avatar URL langsung (untuk DiceBear)
  static Future<String> setWaliAvatarUrl(String avatarUrl) async {
    final token = await AuthService.getToken();
    final uri = Uri.parse('$_baseUrl/wali_update_profile.php');

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
        throw WaliServiceException(
          body['message'] ?? 'Gagal memperbarui avatar',
        );
      }
    } on TimeoutException {
      throw WaliServiceException('Koneksi timeout, coba lagi');
    } on http.ClientException {
      throw WaliServiceException('Tidak dapat terhubung ke server');
    } catch (e) {
      if (e is WaliServiceException) rethrow;
      throw WaliServiceException('Terjadi kesalahan: $e');
    }
  }
}

// ═══════════════════════════════════════
// Data Models
// ═══════════════════════════════════════

class WaliDashboardData {
  final WaliParentInfo parent;
  final List<WaliChildInfo> children;
  final WaliChildInfo? selectedChild;
  final List<WaliPrayerItem> todayPrayers;
  final WaliDailyExtras? todayExtras;
  final WaliTodaySummary? todaySummary;
  final List<WaliBadge> badges;

  WaliDashboardData({
    required this.parent,
    required this.children,
    this.selectedChild,
    required this.todayPrayers,
    this.todayExtras,
    this.todaySummary,
    required this.badges,
  });

  factory WaliDashboardData.fromJson(Map<String, dynamic> json) {
    return WaliDashboardData(
      parent: WaliParentInfo.fromJson(json['parent'] ?? {}),
      children: (json['children'] as List? ?? [])
          .map((c) => WaliChildInfo.fromJson(c))
          .toList(),
      selectedChild: json['selected_child'] != null
          ? WaliChildInfo.fromJson(json['selected_child'])
          : null,
      todayPrayers: (json['today_prayers'] as List? ?? [])
          .map((p) => WaliPrayerItem.fromJson(p))
          .toList(),
      todayExtras: json['today_extras'] != null
          ? WaliDailyExtras.fromJson(json['today_extras'])
          : null,
      todaySummary: json['today_summary'] != null
          ? WaliTodaySummary.fromJson(json['today_summary'])
          : null,
      badges: (json['badges'] as List? ?? [])
          .map((b) => WaliBadge.fromJson(b))
          .toList(),
    );
  }

  WaliDashboardData copyWith({
    WaliParentInfo? parent,
    List<WaliChildInfo>? children,
    WaliChildInfo? selectedChild,
    List<WaliPrayerItem>? todayPrayers,
    WaliDailyExtras? todayExtras,
    WaliTodaySummary? todaySummary,
    List<WaliBadge>? badges,
  }) {
    return WaliDashboardData(
      parent: parent ?? this.parent,
      children: children ?? this.children,
      selectedChild: selectedChild ?? this.selectedChild,
      todayPrayers: todayPrayers ?? this.todayPrayers,
      todayExtras: todayExtras ?? this.todayExtras,
      todaySummary: todaySummary ?? this.todaySummary,
      badges: badges ?? this.badges,
    );
  }
}

class WaliParentInfo {
  final String name;
  final String email;
  final String phone;
  final String? avatarUrl;
  final String? address;
  final double? addressLat;
  final double? addressLng;

  WaliParentInfo({
    required this.name,
    required this.email,
    required this.phone,
    this.avatarUrl,
    this.address,
    this.addressLat,
    this.addressLng,
  });

  factory WaliParentInfo.fromJson(Map<String, dynamic> json) {
    return WaliParentInfo(
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      avatarUrl: json['avatar_url'],
      address: json['address'],
      addressLat: json['address_lat'] != null ? (json['address_lat'] as num).toDouble() : null,
      addressLng: json['address_lng'] != null ? (json['address_lng'] as num).toDouble() : null,
    );
  }
}

class WaliChildInfo {
  final int studentId;
  final String studentName;
  final String? studentAvatar;
  final String nis;
  final String className;
  final String? academicYear;
  final String relationship;
  final int totalPoints;
  final int currentLevel;
  final int streak;

  WaliChildInfo({
    required this.studentId,
    required this.studentName,
    this.studentAvatar,
    required this.nis,
    required this.className,
    this.academicYear,
    required this.relationship,
    required this.totalPoints,
    required this.currentLevel,
    required this.streak,
  });

  /// Ambil inisial nama (2 huruf pertama dari kata pertama & kedua).
  String get initials {
    final parts = studentName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return studentName.isNotEmpty ? studentName[0].toUpperCase() : '?';
  }

  factory WaliChildInfo.fromJson(Map<String, dynamic> json) {
    return WaliChildInfo(
      studentId: json['student_id'] ?? 0,
      studentName: json['student_name'] ?? '',
      studentAvatar: json['student_avatar'],
      nis: json['nis'] ?? '',
      className: json['class_name'] ?? '',
      academicYear: json['academic_year'],
      relationship: json['relationship'] ?? 'wali',
      totalPoints: json['total_points'] ?? 0,
      currentLevel: json['current_level'] ?? 1,
      streak: json['streak'] ?? 0,
    );
  }
}

class WaliPrayerItem {
  final String name;
  final String status; // 'done', 'done_jamaah', 'missed', 'upcoming'
  final int points;

  WaliPrayerItem({
    required this.name,
    required this.status,
    required this.points,
  });

  factory WaliPrayerItem.fromJson(Map<String, dynamic> json) {
    return WaliPrayerItem(
      name: json['name'] ?? '',
      status: json['status'] ?? 'upcoming',
      points: json['points'] ?? 0,
    );
  }

  bool get isDone => status == 'done' || status == 'done_jamaah';
  bool get isJamaah => status == 'done_jamaah';
  bool get isMissed => status == 'missed';
  bool get isUpcoming => status == 'upcoming';
}

class WaliDailyExtras {
  final String? wakeUpTime;
  final int wakeUpPoints;
  final List<String> deeds;
  final int deedsPoints;
  final int comboBonus;
  final int totalExtraPoints;

  WaliDailyExtras({
    this.wakeUpTime,
    required this.wakeUpPoints,
    required this.deeds,
    required this.deedsPoints,
    required this.comboBonus,
    required this.totalExtraPoints,
  });

  factory WaliDailyExtras.fromJson(Map<String, dynamic> json) {
    return WaliDailyExtras(
      wakeUpTime: json['wake_up_time'],
      wakeUpPoints: json['wake_up_points'] ?? 0,
      deeds: (json['deeds'] as List? ?? []).map((d) => d.toString()).toList(),
      deedsPoints: json['deeds_points'] ?? 0,
      comboBonus: json['combo_bonus'] ?? 0,
      totalExtraPoints: json['total_extra_points'] ?? 0,
    );
  }
}

class WaliTodaySummary {
  final String date;
  final int prayersDone;
  final int prayersTotal;
  final int pointsToday;
  final int totalPoints;
  final int streak;
  final int currentLevel;
  final String? lastActiveDate;

  WaliTodaySummary({
    required this.date,
    required this.prayersDone,
    required this.prayersTotal,
    required this.pointsToday,
    required this.totalPoints,
    required this.streak,
    required this.currentLevel,
    this.lastActiveDate,
  });

  factory WaliTodaySummary.fromJson(Map<String, dynamic> json) {
    return WaliTodaySummary(
      date: json['date'] ?? '',
      prayersDone: json['prayers_done'] ?? 0,
      prayersTotal: json['prayers_total'] ?? 5,
      pointsToday: json['points_today'] ?? 0,
      totalPoints: json['total_points'] ?? 0,
      streak: json['streak'] ?? 0,
      currentLevel: json['current_level'] ?? 1,
      lastActiveDate: json['last_active_date'],
    );
  }
}

class WaliBadge {
  final String name;
  final String? description;
  final String? icon;
  final String? gradientColors;
  final String? achievedAt;

  WaliBadge({
    required this.name,
    this.description,
    this.icon,
    this.gradientColors,
    this.achievedAt,
  });

  factory WaliBadge.fromJson(Map<String, dynamic> json) {
    return WaliBadge(
      name: json['name'] ?? '',
      description: json['description'],
      icon: json['icon'],
      gradientColors: json['gradient_colors'],
      achievedAt: json['achieved_at'],
    );
  }
}

/// Custom exception
class WaliServiceException implements Exception {
  final String message;
  WaliServiceException(this.message);

  @override
  String toString() => message;
}

// ═══════════════════════════════════════
// Monthly Calendar Models
// ═══════════════════════════════════════

class WaliMonthlyCalendarData {
  final String month;
  final Map<String, int> heatmap; // { "2026-02-15": 2, ... }
  final WaliMonthlyStats stats;

  WaliMonthlyCalendarData({
    required this.month,
    required this.heatmap,
    required this.stats,
  });

  factory WaliMonthlyCalendarData.fromJson(Map<String, dynamic> json) {
    final rawHeatmap = json['heatmap'] as Map<String, dynamic>? ?? {};
    final heatmap = rawHeatmap.map(
      (key, value) => MapEntry(key, (value is int) ? value : int.tryParse(value.toString()) ?? 0),
    );
    return WaliMonthlyCalendarData(
      month: json['month'] ?? '',
      heatmap: heatmap,
      stats: WaliMonthlyStats.fromJson(json['stats'] ?? {}),
    );
  }
}

class WaliMonthlyStats {
  final int fullDays;
  final double avgPrayer;
  final int maxStreak;
  final int daysWithData;
  final int totalPrayers;

  WaliMonthlyStats({
    required this.fullDays,
    required this.avgPrayer,
    required this.maxStreak,
    required this.daysWithData,
    required this.totalPrayers,
  });

  factory WaliMonthlyStats.fromJson(Map<String, dynamic> json) {
    return WaliMonthlyStats(
      fullDays: json['full_days'] ?? 0,
      avgPrayer: (json['avg_prayer'] is num)
          ? (json['avg_prayer'] as num).toDouble()
          : double.tryParse(json['avg_prayer']?.toString() ?? '0') ?? 0,
      maxStreak: json['max_streak'] ?? 0,
      daysWithData: json['days_with_data'] ?? 0,
      totalPrayers: json['total_prayers'] ?? 0,
    );
  }
}

class WaliDayDetailData {
  final String date;
  final List<WaliPrayerItem> prayers;
  final WaliDailyExtras? extras;
  final int prayersDone;
  final int prayersTotal;
  final bool hasData;

  WaliDayDetailData({
    required this.date,
    required this.prayers,
    this.extras,
    required this.prayersDone,
    required this.prayersTotal,
    required this.hasData,
  });

  factory WaliDayDetailData.fromJson(Map<String, dynamic> json) {
    return WaliDayDetailData(
      date: json['date'] ?? '',
      prayers: (json['prayers'] as List? ?? [])
          .map((p) => WaliPrayerItem.fromJson(p))
          .toList(),
      extras: json['extras'] != null
          ? WaliDailyExtras.fromJson(json['extras'])
          : null,
      prayersDone: json['prayers_done'] ?? 0,
      prayersTotal: json['prayers_total'] ?? 5,
      hasData: json['has_data'] ?? false,
    );
  }
}

// ═══════════════════════════════════════
// Live Timeline Models
// ═══════════════════════════════════════

class WaliLiveTimelineData {
  final List<WaliChildInfo> children;
  final WaliChildInfo? selectedChild;
  final String date;
  final List<WaliTimelinePrayerItem> todayPrayers;
  final WaliLiveSummary summary;
  final List<WaliTimelineEvent> timeline;

  WaliLiveTimelineData({
    required this.children,
    this.selectedChild,
    required this.date,
    required this.todayPrayers,
    required this.summary,
    required this.timeline,
  });

  factory WaliLiveTimelineData.fromJson(Map<String, dynamic> json) {
    return WaliLiveTimelineData(
      children: (json['children'] as List? ?? [])
          .map((c) => WaliChildInfo.fromJson(c))
          .toList(),
      selectedChild: json['selected_child'] != null
          ? WaliChildInfo.fromJson(json['selected_child'])
          : null,
      date: json['date'] ?? '',
      todayPrayers: (json['today_prayers'] as List? ?? [])
          .map((p) => WaliTimelinePrayerItem.fromJson(p))
          .toList(),
      summary: WaliLiveSummary.fromJson(json['summary'] ?? {}),
      timeline: (json['timeline'] as List? ?? [])
          .map((e) => WaliTimelineEvent.fromJson(e))
          .toList(),
    );
  }
}

class WaliTimelinePrayerItem {
  final String name;
  final String status;

  WaliTimelinePrayerItem({required this.name, required this.status});

  factory WaliTimelinePrayerItem.fromJson(Map<String, dynamic> json) {
    return WaliTimelinePrayerItem(
      name: json['name'] ?? '',
      status: json['status'] ?? 'upcoming',
    );
  }

  bool get isDone => status == 'done' || status == 'done_jamaah';
}

class WaliLiveSummary {
  final int prayersDone;
  final int prayersTotal;
  final int pointsToday;
  final int totalPoints;
  final int streak;
  final int currentLevel;
  final int totalEvents;
  final bool isOnline;

  WaliLiveSummary({
    required this.prayersDone,
    required this.prayersTotal,
    required this.pointsToday,
    required this.totalPoints,
    required this.streak,
    required this.currentLevel,
    required this.totalEvents,
    required this.isOnline,
  });

  factory WaliLiveSummary.fromJson(Map<String, dynamic> json) {
    return WaliLiveSummary(
      prayersDone: json['prayers_done'] ?? 0,
      prayersTotal: json['prayers_total'] ?? 5,
      pointsToday: json['points_today'] ?? 0,
      totalPoints: json['total_points'] ?? 0,
      streak: json['streak'] ?? 0,
      currentLevel: json['current_level'] ?? 1,
      totalEvents: json['total_events'] ?? 0,
      isOnline: json['is_online'] ?? false,
    );
  }
}

class WaliTimelineEvent {
  final String description;
  final String timestamp;
  final int points;
  final String type;
  final String? badge;
  final String? detail;

  /// Per-surah grade badges for tahfidz events
  final List<Map<String, String>>? badges;

  /// Data evaluasi guru (hanya ada kalau type == 'evaluasi')
  final int? evaluasiId;
  final Map<String, dynamic>? evaluasiData;

  WaliTimelineEvent({
    required this.description,
    required this.timestamp,
    required this.points,
    required this.type,
    this.badge,
    this.detail,
    this.badges,
    this.evaluasiId,
    this.evaluasiData,
  });

  factory WaliTimelineEvent.fromJson(Map<String, dynamic> json) {
    // Parse badges array for tahfidz per-surah grades
    List<Map<String, String>>? parsedBadges;
    if (json['badges'] is List) {
      parsedBadges = (json['badges'] as List)
          .map((b) => {
                'surah': (b['surah'] ?? '').toString(),
                'grade': (b['grade'] ?? '').toString(),
              })
          .toList();
    }

    return WaliTimelineEvent(
      description: json['description'] ?? '',
      timestamp: json['timestamp'] ?? '',
      points: json['points'] ?? 0,
      type: json['type'] ?? '',
      badge: json['badge']?.toString(),
      detail: json['detail'],
      badges: parsedBadges,
      evaluasiId: json['evaluasi_id'] is int ? json['evaluasi_id'] : null,
      evaluasiData: json['evaluasi_data'] is Map<String, dynamic>
          ? json['evaluasi_data']
          : null,
    );
  }

  /// Format timestamp ke "dd MMM yyyy · HH:mm"
  String get formattedTimestamp {
    try {
      final dt = DateTime.parse(timestamp);
      final months = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
        'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
      ];
      final d = dt.day.toString().padLeft(2, '0');
      final m = months[dt.month];
      final y = dt.year;
      final h = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '$d $m $y · $h:$min';
    } catch (_) {
      return timestamp;
    }
  }
}

// ═══════════════════════════════════════
// Account Center Models
// ═══════════════════════════════════════

class WaliAccountCenterData {
  final WaliParentInfo parent;
  final List<WaliLinkedStudent> linkedStudents;
  final int totalLinked;

  WaliAccountCenterData({
    required this.parent,
    required this.linkedStudents,
    required this.totalLinked,
  });

  factory WaliAccountCenterData.fromJson(Map<String, dynamic> json) {
    return WaliAccountCenterData(
      parent: WaliParentInfo.fromJson(json['parent'] ?? {}),
      linkedStudents: (json['linked_students'] as List? ?? [])
          .map((s) => WaliLinkedStudent.fromJson(s))
          .toList(),
      totalLinked: json['total_linked'] ?? 0,
    );
  }
}

class WaliLinkedStudent {
  final int relationId;
  final int studentId;
  final String studentName;
  final String? studentAvatar;
  final String nis;
  final String className;
  final String? academicYear;
  final String relationship;
  final int totalPoints;
  final int currentLevel;
  final int streak;
  final String? lastActiveDate;
  final String? waliKelas;
  final String? guruTahfidz;

  WaliLinkedStudent({
    required this.relationId,
    required this.studentId,
    required this.studentName,
    this.studentAvatar,
    required this.nis,
    required this.className,
    this.academicYear,
    required this.relationship,
    this.totalPoints = 0,
    this.currentLevel = 1,
    this.streak = 0,
    this.lastActiveDate,
    this.waliKelas,
    this.guruTahfidz,
  });

  String get initials {
    final parts = studentName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return studentName.isNotEmpty ? studentName[0].toUpperCase() : '?';
  }

  String get relationshipLabel {
    switch (relationship) {
      case 'ayah':
        return 'Ayah';
      case 'ibu':
        return 'Ibu';
      case 'wali':
        return 'Wali';
      default:
        return 'Wali';
    }
  }

  String get formattedLastActiveDate {
    if (lastActiveDate == null || lastActiveDate!.isEmpty) {
      return 'Belum pernah aktif';
    }
    try {
      final dt = DateTime.parse(lastActiveDate!);
      final months = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
        'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
      ];
      final d = dt.day.toString().padLeft(2, '0');
      final m = months[dt.month];
      final y = dt.year;
      final h = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '$d $m $y · $h:$min';
    } catch (_) {
      return lastActiveDate!;
    }
  }

  factory WaliLinkedStudent.fromJson(Map<String, dynamic> json) {
    return WaliLinkedStudent(
      relationId: json['relation_id'] ?? 0,
      studentId: json['student_id'] ?? 0,
      studentName: json['student_name'] ?? '',
      studentAvatar: json['student_avatar'],
      nis: json['nis'] ?? '',
      className: json['class_name'] ?? '',
      academicYear: json['academic_year'],
      relationship: json['relationship'] ?? 'wali',
      totalPoints: json['total_points'] ?? 0,
      currentLevel: json['current_level'] ?? 1,
      streak: json['streak'] ?? 0,
      lastActiveDate: json['last_active_date'],
      waliKelas: json['wali_kelas'],
      guruTahfidz: json['guru_tahfidz'],
    );
  }
}
