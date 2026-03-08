import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'prayer_service.dart';
import 'maklumat_service.dart';

/// Data waktu shalat harian (statis daerah Sukoharjo / WIB).
class PrayerSchedule {
  final String name;
  final String arabicName;
  final int hour;
  final int minute;

  const PrayerSchedule({
    required this.name,
    required this.arabicName,
    required this.hour,
    required this.minute,
  });
}

/// Jadwal default shalat 5 waktu (bisa diganti dinamis nanti).
const List<PrayerSchedule> defaultPrayerSchedules = [
  PrayerSchedule(name: 'Subuh', arabicName: 'الفجر', hour: 4, minute: 38),
  PrayerSchedule(name: 'Dzuhur', arabicName: 'الظهر', hour: 12, minute: 15),
  PrayerSchedule(name: 'Ashar', arabicName: 'العصر', hour: 15, minute: 30),
  PrayerSchedule(name: 'Maghrib', arabicName: 'المغرب', hour: 18, minute: 5),
  PrayerSchedule(name: 'Isya', arabicName: 'العشاء', hour: 19, minute: 18),
];

/// Mapping nama shalat → SharedPreferences key.
const Map<String, String> _prayerPrefKeys = {
  'Subuh': 'notif_shalat_fajr',
  'Dzuhur': 'notif_shalat_dhuhur',
  'Ashar': 'notif_shalat_ashr',
  'Maghrib': 'notif_shalat_maghrib',
  'Isya': 'notif_shalat_isya',
};

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // ════════════════════════════════════════
  // Inisialisasi
  // ════════════════════════════════════════

  Future<void> init() async {
    if (_initialized) return;

    // Timezone
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));

    // Android settings
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    // Darwin (iOS/macOS) settings
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _initialized = true;
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('[Notif] Tapped: ${response.payload}');
  }

  // ════════════════════════════════════════
  // Request Permission (Android 13+)
  // ════════════════════════════════════════

  Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }
    return true; // iOS permission dihandle via DarwinInitializationSettings
  }

  // ════════════════════════════════════════
  // Notification Details
  // ════════════════════════════════════════

  NotificationDetails _prayerNotificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'prayer_reminder',
        'Pengingat Shalat',
        channelDescription: 'Notifikasi pengingat waktu shalat 5 waktu',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
        styleInformation: BigTextStyleInformation(''),
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  NotificationDetails _generalNotificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'general',
        'Notifikasi Umum',
        channelDescription: 'Notifikasi umum dari aplikasi Sijawara',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  // ════════════════════════════════════════
  // Kirim Notifikasi Langsung (Instant)
  // ════════════════════════════════════════

  /// Notifikasi instan – untuk testing / trigger manual.
  Future<void> showInstant({
    required int id,
    required String title,
    required String body,
    String? payload,
    bool isPrayer = false,
  }) async {
    await _plugin.show(
      id,
      title,
      body,
      isPrayer ? _prayerNotificationDetails() : _generalNotificationDetails(),
      payload: payload,
    );
  }

  // ════════════════════════════════════════
  // Schedule Notifikasi Shalat Hari Ini
  // ════════════════════════════════════════

  /// Jadwalkan notifikasi shalat yang belum lewat hari ini,
  /// sesuai toggle di SharedPreferences.
  Future<int> scheduleTodayPrayerNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final masterEnabled = prefs.getBool('notif_master') ?? true;

    // Batalkan semua notifikasi shalat lama (ID 100-104)
    for (int i = 100; i <= 104; i++) {
      await _plugin.cancel(i);
    }

    if (!masterEnabled) return 0;

    final now = tz.TZDateTime.now(tz.local);
    int scheduled = 0;

    for (int i = 0; i < defaultPrayerSchedules.length; i++) {
      final prayer = defaultPrayerSchedules[i];
      final prefKey = _prayerPrefKeys[prayer.name] ?? '';
      final enabled = prefs.getBool(prefKey) ?? true;

      if (!enabled) continue;

      final scheduledTime = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        prayer.hour,
        prayer.minute,
      );

      // Hanya jadwalkan jika waktu belum lewat
      if (scheduledTime.isAfter(now)) {
        await _plugin.zonedSchedule(
          100 + i, // ID unik per shalat
          '🕌 Waktu ${prayer.name} telah tiba',
          'Saatnya menunaikan shalat ${prayer.name} (${prayer.arabicName}). '
              'Jangan lupa catat ibadahmu hari ini!',
          scheduledTime,
          _prayerNotificationDetails(),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: 'prayer_${prayer.name.toLowerCase()}',
        );
        scheduled++;
        debugPrint(
            '[Notif] Scheduled ${prayer.name} at ${prayer.hour}:${prayer.minute.toString().padLeft(2, '0')}');
      }
    }

    return scheduled;
  }

  // ════════════════════════════════════════
  // Trigger Test: Semua Notifikasi Shalat
  // ════════════════════════════════════════

  /// Kirim notifikasi untuk shalat yang waktunya sudah lewat
  /// tapi belum dicatat oleh user hari ini.
  Future<int> triggerTestPrayerNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final masterEnabled = prefs.getBool('notif_master') ?? true;
    if (!masterEnabled) return 0;

    // Ambil data shalat hari ini dari API
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    Map<String, PrayerLogEntry> todayPrayers = {};
    try {
      final dayData = await PrayerService.getPrayersByDate(today);
      todayPrayers = dayData.prayers;
    } catch (e) {
      debugPrint('[Notif] Gagal ambil data shalat: $e');
      // Lanjut saja, anggap semua belum dicatat
    }

    int sent = 0;
    final now = DateTime.now();

    for (int i = 0; i < defaultPrayerSchedules.length; i++) {
      final prayer = defaultPrayerSchedules[i];
      final prefKey = _prayerPrefKeys[prayer.name] ?? '';
      final enabled = prefs.getBool(prefKey) ?? true;
      if (!enabled) continue;

      final timeStr =
          '${prayer.hour.toString().padLeft(2, '0')}:${prayer.minute.toString().padLeft(2, '0')}';

      // Tentukan status: sudah lewat / belum
      final prayerToday = DateTime(
          now.year, now.month, now.day, prayer.hour, prayer.minute);
      final isPast = now.isAfter(prayerToday);

      // Cek apakah shalat ini sudah dicatat di API
      final logged = todayPrayers[prayer.name];
      final alreadyRecorded = logged != null &&
          (logged.status == 'done' || logged.status == 'done_jamaah');

      if (isPast && alreadyRecorded) {
        // Sudah lewat dan sudah dicatat → skip, tidak perlu notifikasi
        debugPrint('[Notif] ${prayer.name} sudah dicatat, skip notif');
        continue;
      }

      if (isPast && !alreadyRecorded) {
        // Sudah lewat tapi BELUM dicatat → ingatkan user
        await showInstant(
          id: 200 + i,
          title: 'Sudah Shalat ${prayer.name}?',
          body: 'Waktu ${prayer.name} ($timeStr) sudah lewat hari ini. '
              'Sudahkah kamu menunaikannya? Yuk catat ibadahmu!',
          payload: 'test_prayer_${prayer.name.toLowerCase()}',
          isPrayer: true,
        );
        sent++;
      } else if (!isPast) {
        // Belum lewat → ingatkan untuk bersiap
        await showInstant(
          id: 200 + i,
          title: 'Pengingat Shalat ${prayer.name}',
          body: 'Waktu ${prayer.name} ($timeStr) akan tiba. '
              'Bersiaplah menunaikan shalat ${prayer.name}!',
          payload: 'test_prayer_${prayer.name.toLowerCase()}',
          isPrayer: true,
        );
        sent++;
      }

      // Delay sedikit agar notifikasi muncul satu per satu
      await Future.delayed(const Duration(milliseconds: 300));
    }

    return sent;
  }

  // ════════════════════════════════════════
  // Notifikasi Pengumuman Sekolah (Maklumat)
  // ════════════════════════════════════════

  static const String _lastMaklumatIdKey = 'notif_last_maklumat_id';

  NotificationDetails _announcementNotificationDetails(String prioritas) {
    final isHigh = prioritas == 'Tinggi';
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'school_announcement',
        'Pengumuman Sekolah',
        channelDescription: 'Notifikasi pengumuman dan maklumat sekolah',
        importance: isHigh ? Importance.high : Importance.defaultImportance,
        priority: isHigh ? Priority.high : Priority.defaultPriority,
        icon: '@mipmap/ic_launcher',
        playSound: isHigh,
        enableVibration: isHigh,
        styleInformation: const BigTextStyleInformation(''),
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  /// Cek maklumat baru dari server, tampilkan notifikasi
  /// untuk yang belum pernah di-notify.
  /// Dipanggil saat siswa membuka aplikasi atau resume.
  Future<int> checkNewMaklumat() async {
    final prefs = await SharedPreferences.getInstance();
    final masterEnabled = prefs.getBool('notif_master') ?? true;
    final pengumumanEnabled = prefs.getBool('notif_pengumuman') ?? true;

    if (!masterEnabled || !pengumumanEnabled) return 0;

    // Request permission dulu (Android 13+)
    final granted = await requestPermission();
    if (!granted) {
      debugPrint('[Notif] Izin notifikasi ditolak, skip cek maklumat');
      return 0;
    }

    // Cek apakah ini pertama kali (belum pernah set baseline)
    final isFirstRun = !prefs.containsKey(_lastMaklumatIdKey);

    try {
      final items = await MaklumatService.getStudentMaklumat();
      if (items.isEmpty) {
        // Tidak ada maklumat sama sekali, set baseline ke 0
        if (isFirstRun) await prefs.setInt(_lastMaklumatIdKey, 0);
        return 0;
      }

      // Cari ID terbesar dari semua maklumat
      final maxId = items.map((m) => m.id).reduce((a, b) => a > b ? a : b);

      // Pertama kali: set baseline tanpa mengirim notifikasi
      // agar maklumat lama tidak spam notifikasi
      if (isFirstRun) {
        await prefs.setInt(_lastMaklumatIdKey, maxId);
        debugPrint('[Notif] First run, set baseline maklumat ID: $maxId');
        return 0;
      }

      final lastNotifiedId = prefs.getInt(_lastMaklumatIdKey) ?? 0;

      // Filter hanya maklumat baru (ID > lastNotifiedId)
      final newItems = items.where((m) => m.id > lastNotifiedId).toList();
      if (newItems.isEmpty) return 0;

      int sent = 0;

      for (final maklumat in newItems) {
        // Potong deskripsi agar tidak terlalu panjang di notifikasi
        final shortDesc = maklumat.deskripsi.length > 120
            ? '${maklumat.deskripsi.substring(0, 120)}...'
            : maklumat.deskripsi;

        await _plugin.show(
          300 + (maklumat.id % 100), // ID notifikasi unik
          maklumat.judul,
          shortDesc,
          _announcementNotificationDetails(maklumat.prioritas),
          payload: 'maklumat_${maklumat.id}',
        );
        sent++;

        // Delay antar notifikasi
        if (sent < newItems.length) {
          await Future.delayed(const Duration(milliseconds: 400));
        }
      }

      // Simpan ID terbaru agar tidak notify ulang
      final newMaxId =
          newItems.map((m) => m.id).reduce((a, b) => a > b ? a : b);
      await prefs.setInt(_lastMaklumatIdKey, newMaxId);

      debugPrint(
          '[Notif] $sent maklumat baru dinotifikasi (last ID: $newMaxId)');
      return sent;
    } catch (e) {
      debugPrint('[Notif] Gagal cek maklumat baru: $e');
      return 0;
    }
  }

  // ════════════════════════════════════════
  // Cancel
  // ════════════════════════════════════════

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  Future<void> cancel(int id) async {
    await _plugin.cancel(id);
  }
}
