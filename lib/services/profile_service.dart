import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

/// Service untuk komunikasi dengan API profile & leaderboard.
class ProfileService {
  static const String _baseUrl = 'https://portal-smalka.com/api';

  // ═══════════════════════════════════════
  // GET: Ambil data profil lengkap
  // ═══════════════════════════════════════
  static Future<ProfileData> getProfile() async {
    final token = await AuthService.getToken();
    final uri = Uri.parse('$_baseUrl/profile.php');

    try {
      final response = await http.get(uri, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      }).timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        return ProfileData.fromJson(body['data']);
      } else {
        throw ProfileServiceException(
          body['message'] ?? 'Gagal mengambil data profil',
        );
      }
    } on TimeoutException {
      throw ProfileServiceException('Koneksi timeout, coba lagi');
    } on http.ClientException {
      throw ProfileServiceException('Tidak dapat terhubung ke server');
    } on FormatException {
      throw ProfileServiceException('Response server tidak valid');
    } catch (e) {
      if (e is ProfileServiceException) rethrow;
      throw ProfileServiceException('Terjadi kesalahan: $e');
    }
  }

  // ═══════════════════════════════════════
  // GET: Ambil data leaderboard
  // ═══════════════════════════════════════
  static Future<LeaderboardData> getLeaderboard({
    int? classId,
    int limit = 50,
  }) async {
    final token = await AuthService.getToken();
    final params = <String, String>{
      'limit': limit.toString(),
    };
    if (classId != null) params['class_id'] = classId.toString();

    final uri = Uri.parse('$_baseUrl/leaderboard.php')
        .replace(queryParameters: params);

    try {
      final response = await http.get(uri, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      }).timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        return LeaderboardData.fromJson(body['data']);
      } else {
        throw ProfileServiceException(
          body['message'] ?? 'Gagal mengambil data leaderboard',
        );
      }
    } on TimeoutException {
      throw ProfileServiceException('Koneksi timeout, coba lagi');
    } on http.ClientException {
      throw ProfileServiceException('Tidak dapat terhubung ke server');
    } on FormatException {
      throw ProfileServiceException('Response server tidak valid');
    } catch (e) {
      if (e is ProfileServiceException) rethrow;
      throw ProfileServiceException('Terjadi kesalahan: $e');
    }
  }

  // ═══════════════════════════════════════
  // GET: Ambil detail siswa (untuk bottom sheet)
  // ═══════════════════════════════════════
  static Future<StudentDetail?> getStudentDetail(int studentId) async {
    final token = await AuthService.getToken();
    final uri = Uri.parse(
        '$_baseUrl/leaderboard.php?detail_student_id=$studentId&limit=1');

    try {
      final response = await http.get(uri, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      }).timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        final data = body['data'];
        if (data['student_detail'] != null) {
          return StudentDetail.fromJson(data['student_detail']);
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

// ═══════════════════════════════════════
// DATA MODELS
// ═══════════════════════════════════════

class ProfileData {
  final StudentProfile profile;
  final List<int> weeklyPoints;
  final List<String> dayLabels;
  final List<int> monthlyPoints;
  final List<PointSource> pointsBreakdown;
  final List<BadgeInfo> badges;
  final List<String> newBadges;
  final Map<String, int> trackingStats;

  ProfileData({
    required this.profile,
    required this.weeklyPoints,
    required this.dayLabels,
    required this.monthlyPoints,
    required this.pointsBreakdown,
    required this.badges,
    required this.newBadges,
    required this.trackingStats,
  });

  factory ProfileData.fromJson(Map<String, dynamic> json) {
    final profileJson = json['profile'] as Map<String, dynamic>;
    final weeklyList = (json['weekly_points'] as List).cast<int>();
    final dayList = (json['day_labels'] as List).cast<String>();
    final monthlyList = (json['monthly_points'] as List?)?.cast<int>() ?? List.filled(12, 0);

    final breakdownList = (json['points_breakdown'] as List)
        .map((e) => PointSource.fromJson(e as Map<String, dynamic>))
        .toList();

    final badgeList = (json['badges'] as List)
        .map((e) => BadgeInfo.fromJson(e as Map<String, dynamic>))
        .toList();

    final newBadges = (json['new_badges'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    final tracking = <String, int>{};
    if (json['tracking_stats'] is Map) {
      (json['tracking_stats'] as Map).forEach((k, v) {
        tracking[k.toString()] = (v is int) ? v : int.tryParse(v.toString()) ?? 0;
      });
    }

    return ProfileData(
      profile: StudentProfile.fromJson(profileJson),
      weeklyPoints: weeklyList,
      dayLabels: dayList,
      monthlyPoints: monthlyList,
      pointsBreakdown: breakdownList,
      badges: badgeList,
      newBadges: newBadges,
      trackingStats: tracking,
    );
  }
}

class StudentProfile {
  final int studentId;
  final String name;
  final String? email;
  final String? phone;
  final String? avatarUrl;
  final String className;
  final String schoolName;
  final int totalPoints;
  final int currentLevel;
  final int pointsForNextLevel;
  final int streak;
  final String? lastActiveDate;

  StudentProfile({
    required this.studentId,
    required this.name,
    this.email,
    this.phone,
    this.avatarUrl,
    required this.className,
    required this.schoolName,
    required this.totalPoints,
    required this.currentLevel,
    required this.pointsForNextLevel,
    required this.streak,
    this.lastActiveDate,
  });

  factory StudentProfile.fromJson(Map<String, dynamic> json) {
    return StudentProfile(
      studentId: json['student_id'] as int,
      name: json['name'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      className: json['class_name'] as String? ?? '-',
      schoolName: json['school_name'] as String? ??
          'SMA Muhammadiyah Al Kautsar Program Khusus',
      totalPoints: json['total_points'] as int? ?? 0,
      currentLevel: json['current_level'] as int? ?? 1,
      pointsForNextLevel: json['points_for_next_level'] as int? ?? 300,
      streak: json['streak'] as int? ?? 0,
      lastActiveDate: json['last_active_date'] as String?,
    );
  }
}

class PointSource {
  final String source;
  final String label;
  final String iconName;
  final String colorHex;
  final int points;

  PointSource({
    required this.source,
    required this.label,
    required this.iconName,
    required this.colorHex,
    required this.points,
  });

  factory PointSource.fromJson(Map<String, dynamic> json) {
    return PointSource(
      source: json['source'] as String,
      label: json['label'] as String,
      iconName: json['icon'] as String? ?? 'star_rounded',
      colorHex: json['color'] as String? ?? '#059669',
      points: json['points'] as int? ?? 0,
    );
  }

  /// Konversi hex color string ke Color
  Color get color {
    final hex = colorHex.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  /// Konversi icon name ke IconData
  IconData get icon {
    return _iconMap[iconName] ?? Icons.star_rounded;
  }
}

class BadgeInfo {
  final int id;
  final String name;
  final String description;
  final String iconName;
  final String? requirementType;
  final int? requirementValue;
  final String? gradientColors;
  final bool isAchieved;
  final String? achievedAt;

  BadgeInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.iconName,
    this.requirementType,
    this.requirementValue,
    this.gradientColors,
    required this.isAchieved,
    this.achievedAt,
  });

  factory BadgeInfo.fromJson(Map<String, dynamic> json) {
    return BadgeInfo(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      iconName: json['icon'] as String? ?? 'star_rounded',
      requirementType: json['requirement_type'] as String?,
      requirementValue: json['requirement_value'] as int?,
      gradientColors: json['gradient_colors'] as String?,
      isAchieved: json['is_achieved'] as bool? ?? false,
      achievedAt: json['achieved_at'] as String?,
    );
  }

  IconData get icon => _iconMap[iconName] ?? Icons.star_rounded;

  LinearGradient get gradient {
    if (gradientColors == null || gradientColors!.isEmpty) {
      return const LinearGradient(colors: [Color(0xFF059669), Color(0xFF34D399)]);
    }
    final parts = gradientColors!.split(',');
    final colors = parts.map((hex) {
      final h = hex.trim().replaceAll('#', '');
      return Color(int.parse('FF$h', radix: 16));
    }).toList();

    if (colors.length < 2) {
      colors.add(colors.first.withOpacity(0.7));
    }
    return LinearGradient(colors: colors);
  }
}

class LeaderboardData {
  final List<LeaderboardEntry> leaderboard;
  final int? myRank;
  final int myStudentId;
  final int totalStudents;

  LeaderboardData({
    required this.leaderboard,
    this.myRank,
    required this.myStudentId,
    required this.totalStudents,
  });

  factory LeaderboardData.fromJson(Map<String, dynamic> json) {
    final list = (json['leaderboard'] as List)
        .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
        .toList();

    return LeaderboardData(
      leaderboard: list,
      myRank: json['my_rank'] as int?,
      myStudentId: json['my_student_id'] as int? ?? 0,
      totalStudents: json['total_students'] as int? ?? 0,
    );
  }
}

class LeaderboardEntry {
  final int studentId;
  final String name;
  final String? avatarUrl;
  final String className;
  final int totalPoints;
  final int currentLevel;
  final int streak;
  final int badgeCount;
  final int rank;
  final bool isMe;

  LeaderboardEntry({
    required this.studentId,
    required this.name,
    this.avatarUrl,
    required this.className,
    required this.totalPoints,
    required this.currentLevel,
    required this.streak,
    required this.badgeCount,
    required this.rank,
    required this.isMe,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      studentId: json['student_id'] as int,
      name: json['name'] as String,
      avatarUrl: json['avatar_url'] as String?,
      className: json['class_name'] as String? ?? '-',
      totalPoints: json['total_points'] as int? ?? 0,
      currentLevel: json['current_level'] as int? ?? 1,
      streak: json['streak'] as int? ?? 0,
      badgeCount: json['badge_count'] as int? ?? 0,
      rank: json['rank'] as int? ?? 0,
      isMe: json['is_me'] as bool? ?? false,
    );
  }
}

class StudentDetail {
  final int studentId;
  final String name;
  final String? avatarUrl;
  final String className;
  final int totalPoints;
  final int currentLevel;
  final int streak;
  final List<BadgeInfo> badges;

  StudentDetail({
    required this.studentId,
    required this.name,
    this.avatarUrl,
    required this.className,
    required this.totalPoints,
    required this.currentLevel,
    required this.streak,
    required this.badges,
  });

  factory StudentDetail.fromJson(Map<String, dynamic> json) {
    final badgeList = (json['badges'] as List?)
            ?.map((e) => BadgeInfo.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return StudentDetail(
      studentId: json['student_id'] as int,
      name: json['name'] as String,
      avatarUrl: json['avatar_url'] as String?,
      className: json['class_name'] as String? ?? '-',
      totalPoints: json['total_points'] as int? ?? 0,
      currentLevel: json['current_level'] as int? ?? 1,
      streak: json['streak'] as int? ?? 0,
      badges: badgeList,
    );
  }
}

/// Custom exception for profile service errors.
class ProfileServiceException implements Exception {
  final String message;

  ProfileServiceException(this.message);

  @override
  String toString() => message;
}

// ═══════════════════════════════════════
// ICON MAP: server icon name → Flutter IconData
// ═══════════════════════════════════════
const Map<String, IconData> _iconMap = {
  'local_fire_department_rounded': Icons.local_fire_department_rounded,
  'auto_awesome_rounded': Icons.auto_awesome_rounded,
  'star_rounded': Icons.star_rounded,
  'emoji_events_rounded': Icons.emoji_events_rounded,
  'mosque_rounded': Icons.mosque_rounded,
  'menu_book_rounded': Icons.menu_book_rounded,
  'favorite_rounded': Icons.favorite_rounded,
  'volunteer_activism_rounded': Icons.volunteer_activism_rounded,
  'shield_rounded': Icons.shield_rounded,
  'record_voice_over_rounded': Icons.record_voice_over_rounded,
  'school_rounded': Icons.school_rounded,
  'edit_note_rounded': Icons.edit_note_rounded,
  'wb_sunny_rounded': Icons.wb_sunny_rounded,
  'bolt_rounded': Icons.bolt_rounded,
  'pie_chart_rounded': Icons.pie_chart_rounded,
  'bar_chart_rounded': Icons.bar_chart_rounded,
  'person_rounded': Icons.person_rounded,
  'military_tech_rounded': Icons.military_tech_rounded,
};
