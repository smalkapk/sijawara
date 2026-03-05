import '../services/prayer_service.dart';
import '../services/profile_service.dart';
import '../services/tahfidz_service.dart';

/// Static in-memory cache untuk menyimpan data terakhir dari ketiga halaman siswa.
/// Data dipertahankan selama sesi aplikasi, dan dapat di-invalidasi
/// secara manual (misalnya saat pull-to-refresh).
class PageCache {
  PageCache._();

  // ── HOME PAGE ──
  static StudentData? homeStudentData;
  static DateTime? homeTimestamp;

  // ── PROFILE PAGE ──
  static ProfileData? profileData;
  static DateTime? profileTimestamp;
  static LeaderboardData? leaderboardData;
  static DateTime? leaderboardTimestamp;

  // ── QURAN PAGE ──
  static List<TahfidzSetoran>? setoranList;
  static DateTime? setoranTimestamp;

  /// Cek apakah cache masih dianggap segar.
  /// Default: cache valid selama [maxAgeMinutes] menit (default 30 menit).
  static bool isFresh(DateTime? timestamp, {int maxAgeMinutes = 30}) {
    if (timestamp == null) return false;
    return DateTime.now().difference(timestamp).inMinutes < maxAgeMinutes;
  }

  /// Bersihkan semua cache (dipakai saat logout atau kebutuhan khusus).
  static void clearAll() {
    homeStudentData = null;
    homeTimestamp = null;
    profileData = null;
    profileTimestamp = null;
    leaderboardData = null;
    leaderboardTimestamp = null;
    setoranList = null;
    setoranTimestamp = null;
  }

  /// Bersihkan cache halaman Beranda saja.
  static void clearHome() {
    homeStudentData = null;
    homeTimestamp = null;
  }

  /// Bersihkan cache halaman Profil saja.
  static void clearProfile() {
    profileData = null;
    profileTimestamp = null;
    leaderboardData = null;
    leaderboardTimestamp = null;
  }

  /// Bersihkan cache halaman Qur'an saja.
  static void clearQuran() {
    setoranList = null;
    setoranTimestamp = null;
  }
}
