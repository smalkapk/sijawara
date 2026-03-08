import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import '../main.dart' show navigatorKey;
import '../pages/guru_chat_page.dart';
import '../pages/wali_diskusi_guru_page.dart';
import '../pages/wali_public_speaking_page.dart';
import '../pages/wali_diskusi_page.dart';

/// Download gambar dari URL dan convert ke circular ByteArrayAndroidBitmap
/// untuk digunakan sebagai largeIcon notifikasi (seperti WhatsApp).
Future<ByteArrayAndroidBitmap?> _downloadCircleAvatar(String url) async {
  try {
    if (url.isEmpty) return null;
    final response = await http.get(Uri.parse(url)).timeout(
      const Duration(seconds: 5),
    );
    if (response.statusCode != 200) return null;

    final Uint8List imageBytes = response.bodyBytes;

    // Decode image
    final ui.Codec codec = await ui.instantiateImageCodec(
      imageBytes,
      targetWidth: 256,
      targetHeight: 256,
    );
    final ui.FrameInfo frame = await codec.getNextFrame();
    final ui.Image original = frame.image;

    // Create circular avatar
    final int size = 256;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Draw circle clip
    final paint = Paint()..isAntiAlias = true;
    canvas.drawCircle(
      Offset(size / 2, size / 2),
      size / 2,
      paint,
    );

    // Clip to circle and draw image
    canvas.clipPath(
      Path()..addOval(Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble())),
    );
    canvas.drawImageRect(
      original,
      Rect.fromLTWH(
          0, 0, original.width.toDouble(), original.height.toDouble()),
      Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
      Paint(),
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(size, size);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    original.dispose();
    img.dispose();

    if (byteData == null) return null;
    return ByteArrayAndroidBitmap(byteData.buffer.asUint8List());
  } catch (e) {
    debugPrint('[FCM] Failed to download avatar: $e');
    return null;
  }
}

/// Top-level background message handler (wajib top-level function).
/// Dipanggil saat app di-kill atau di background.
/// Jika FCM message punya `notification` payload → Android otomatis tampilkan.
/// Jika hanya `data` payload → kita tampilkan manual via flutter_local_notifications.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // WAJIB: init Firebase di background isolate (isolate terpisah dari main)
  await Firebase.initializeApp();
  debugPrint('[FCM] Background message: ${message.messageId}');
  debugPrint('[FCM] Background data: ${message.data}');
  debugPrint('[FCM] Background notification: ${message.notification?.title}');

  // Jika TIDAK ada notification payload (data-only message),
  // tampilkan notifikasi manual agar tetap muncul di system tray.
  if (message.notification == null) {
    final data = message.data;
    final type = data['type'] ?? '';

    String title;
    String body;
    String channelId;
    String channelName;

    if (type == 'task_submitted') {
      title = data['title'] ?? 'Ananda Baru Saja Mengerjakan Tugas';
      body = data['body'] ?? 'Ananda baru saja mengerjakan tugas, klik untuk melihat!';
      channelId = 'task_channel';
      channelName = 'Tugas Siswa';
    } else if (type == 'chat') {
      title = data['sender_name'] ?? 'Pesan Baru';
      body = data['message'] ?? 'Anda menerima pesan baru';
      channelId = 'chat_channel';
      channelName = 'Pesan Chat';
    } else {
      return; // Unknown type, skip
    }

    final localNotif = FlutterLocalNotificationsPlugin();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await localNotif.initialize(
      const InitializationSettings(android: androidInit),
    );

    if (type == 'chat') {

      // Download avatar pengirim untuk large icon
      ByteArrayAndroidBitmap? avatar;
      final avatarUrl = data['sender_avatar'] ?? '';
      if (avatarUrl.isNotEmpty) {
        avatar = await _downloadCircleAvatar(avatarUrl);
      }

      await localNotif.show(
        'chat_${data['sender_id'] ?? ''}'.hashCode,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            channelDescription: 'Pesan chat dari diskusi guru & wali',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            largeIcon: avatar,
            playSound: true,
            enableVibration: true,
            styleInformation: BigTextStyleInformation(body),
          ),
        ),
        payload: jsonEncode(data),
      );
    } else {
      // task_submitted notification
      await localNotif.show(
        'task_${data['task_type'] ?? ''}_${data['student_id'] ?? ''}'.hashCode,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            channelDescription: 'Notifikasi tugas siswa',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            playSound: true,
            enableVibration: true,
            styleInformation: BigTextStyleInformation(body),
          ),
        ),
        payload: jsonEncode(data),
      );
    }
  }
}

class FcmService with WidgetsBindingObserver {
  FcmService._();
  static final FcmService instance = FcmService._();

  static const String _baseUrl = 'https://portal-smalka.com/api';
  static const String _tokenSentKey = 'fcm_token_sent';
  static const String _lastTokenKey = 'fcm_last_token';
  static const int _tokenRetryMaxAttempts = 3;

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotif =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Apakah app sedang di foreground.
  /// Digunakan untuk menentukan apakah perlu suppress notifikasi.
  bool _isAppInForeground = true;

  /// ID user yang sedang aktif di-chat (untuk suppress notifikasi foreground).
  /// Diset oleh halaman chat saat dibuka/ditutup.
  int? activeChatPartnerId;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppInForeground = state == AppLifecycleState.resumed;
    debugPrint('[FCM] App lifecycle: $state, foreground=$_isAppInForeground');
  }

  // ════════════════════════════════════════
  // Inisialisasi FCM
  // ════════════════════════════════════════

  Future<void> init() async {
    if (_initialized) return;

    // Request permission (Android 13+ / iOS)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    debugPrint('[FCM] Permission status: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('[FCM] Notification permission denied');
      return;
    }

    // Register lifecycle observer
    WidgetsBinding.instance.addObserver(this);

    // Setup foreground notification channel (Android)
    await _setupLocalNotificationChannel();

    // Inisialisasi flutter_local_notifications dengan tap handler
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _localNotif.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    // iOS: Pastikan notifikasi tidak auto-show di foreground
    // (kita handle manual via flutter_local_notifications)
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: true,
      sound: false,
    );

    // Listen foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Listen saat user tap notifikasi (app di background lalu dibuka)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Cek jika app dibuka dari notifikasi (terminated state)
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    // Dapatkan & kirim token ke server (dengan retry)
    await _handleTokenWithRetry();

    // Listen token refresh
    _messaging.onTokenRefresh.listen((newToken) {
      debugPrint('[FCM] Token refreshed');
      _sendTokenToServer(newToken);
    });

    _initialized = true;
    debugPrint('[FCM] Service initialized');
  }

  // ════════════════════════════════════════
  // Foreground Message Handler
  // ════════════════════════════════════════

  /// Saat app di foreground, FCM tidak otomatis menampilkan notifikasi.
  /// Kita tampilkan manual via flutter_local_notifications.
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('[FCM] Foreground message received (appForeground=$_isAppInForeground)');
    debugPrint('[FCM]   notification: ${message.notification?.title} / ${message.notification?.body}');
    debugPrint('[FCM]   data: ${message.data}');
    debugPrint('[FCM]   activeChatPartnerId: $activeChatPartnerId');

    final notification = message.notification;
    final data = message.data;
    final type = data['type'] ?? '';

    // ── Suppress chat notification HANYA jika:
    //    1. App ada di foreground, DAN
    //    2. User sedang membuka halaman chat dengan pengirim yang sama
    if (type == 'chat' && _isAppInForeground) {
      final senderId = int.tryParse(data['sender_id'] ?? '');
      if (senderId != null && senderId == activeChatPartnerId) {
        debugPrint('[FCM] Suppressed: user sedang chat dengan sender $senderId');
        return;
      }
    }

    // Ambil title & body dari notification payload, atau dari data jika notification null
    String title;
    String body;

    if (type == 'task_submitted') {
      title = notification?.title ?? 'Ananda Baru Saja Mengerjakan Tugas';
      body = notification?.body ?? data['body'] ?? 'Ananda baru saja mengerjakan tugas, klik untuk melihat!';
    } else {
      title = notification?.title ?? data['sender_name'] ?? 'Notifikasi';
      body = notification?.body ?? data['message'] ?? '';
    }

    if (title.isEmpty && body.isEmpty) {
      debugPrint('[FCM] Skipped: no title/body to show');
      return;
    }

    final bool isChat = type == 'chat';
    final bool isTask = type == 'task_submitted';
    final String channelId = isChat
        ? 'chat_channel'
        : isTask
            ? 'task_channel'
            : 'fcm_channel';
    final String channelName = isChat
        ? 'Pesan Chat'
        : isTask
            ? 'Tugas Siswa'
            : 'Notifikasi Push';

    // Untuk chat: download avatar pengirim untuk large icon
    ByteArrayAndroidBitmap? avatar;
    if (isChat) {
      final avatarUrl = data['sender_avatar'] ?? '';
      if (avatarUrl.isNotEmpty) {
        avatar = await _downloadCircleAvatar(avatarUrl);
      }
    }

    // Untuk chat guru: grouping berdasarkan sender
    String? groupKey;
    int notifId = title.hashCode ^ body.hashCode;
    if (isChat) {
      groupKey = 'chat_messages';
      // Gunakan sender_id hash sebagai notif ID agar pesan dari
      // sender yang sama meng-update notifikasi sebelumnya
      final senderId = data['sender_id'] ?? '';
      notifId = 'chat_$senderId'.hashCode;
    } else if (isTask) {
      // Setiap submit tugas beda → unique notif ID
      notifId = 'task_${data['task_type'] ?? ''}_${data['student_id'] ?? ''}'.hashCode;
    }

    debugPrint('[FCM] Showing local notification: $title / $body (chat=$isChat, task=$isTask, hasAvatar=${avatar != null})');

    await _localNotif.show(
      notifId,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: isChat
              ? 'Pesan chat dari diskusi guru & wali'
              : 'Notifikasi push dari server Sijawara',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          largeIcon: avatar,
          playSound: true,
          enableVibration: true,
          groupKey: groupKey,
          setAsGroupSummary: false,
          styleInformation: BigTextStyleInformation(body),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(data),
    );

    // Tampilkan summary notification untuk group chat (Android)
    if (isChat) {
      await _localNotif.show(
        'chat_summary'.hashCode,
        'Pesan baru',
        'Anda memiliki pesan chat baru',
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            channelDescription: 'Pesan chat dari diskusi guru & wali',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            groupKey: groupKey,
            setAsGroupSummary: true,
            styleInformation: const InboxStyleInformation(
              [],
              contentTitle: 'Pesan Chat Baru',
              summaryText: 'Diskusi Guru & Wali',
            ),
          ),
        ),
      );
    }
  }

  // ════════════════════════════════════════
  // Notification Tap Handler
  // ════════════════════════════════════════

  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('[FCM] Notification tapped: ${message.data}');
    _navigateByData(message.data);
  }

  /// Callback ketika user tap notifikasi lokal (flutter_local_notifications).
  void _onLocalNotificationTap(NotificationResponse response) {
    debugPrint('[FCM] Local notification tapped, payload: ${response.payload}');
    if (response.payload != null && response.payload!.isNotEmpty) {
      try {
        final data = Map<String, dynamic>.from(jsonDecode(response.payload!));
        _navigateByData(data);
      } catch (e) {
        debugPrint('[FCM] Error parsing local notif payload: $e');
      }
    }
  }

  /// Navigasi ke halaman yang sesuai berdasarkan data notifikasi.
  void _navigateByData(Map<String, dynamic> data) {
    final type = data['type'] ?? '';
    final nav = navigatorKey.currentState;

    if (nav == null) {
      debugPrint('[FCM] Navigator belum tersedia, skip navigasi');
      return;
    }

    switch (type) {
      case 'chat':
        final senderIdStr = data['sender_id'] ?? '';
        final senderId = int.tryParse(senderIdStr);
        final senderName = data['sender_name'] ?? 'Pengirim';
        final senderRole = data['sender_role'] ?? '';

        if (senderId == null) {
          debugPrint('[FCM] Chat notification tanpa sender_id');
          return;
        }

        if (senderRole == 'orang_tua') {
          // Guru menerima chat dari wali → buka GuruChatPage
          nav.push(
            MaterialPageRoute(
              builder: (_) => GuruChatPage(
                waliId: senderId,
                waliName: senderName,
              ),
            ),
          );
        } else {
          // Wali menerima chat dari guru → buka WaliDiskusiGuruPage
          nav.push(
            MaterialPageRoute(
              builder: (_) => const WaliDiskusiGuruPage(),
            ),
          );
        }
        break;

      case 'task_submitted':
        final taskType = data['task_type'] ?? '';
        final studentIdStr = data['student_id'] ?? '';
        final studentId = int.tryParse(studentIdStr);

        debugPrint('[FCM] Task notification: taskType=$taskType, studentId=$studentId');

        if (taskType == 'public_speaking') {
          nav.push(
            MaterialPageRoute(
              builder: (_) => WaliPublicSpeakingPage(studentId: studentId),
            ),
          );
        } else if (taskType == 'diskusi') {
          nav.push(
            MaterialPageRoute(
              builder: (_) => WaliDiskusiPage(studentId: studentId),
            ),
          );
        } else {
          debugPrint('[FCM] Unknown task_type: $taskType');
        }
        break;

      default:
        debugPrint('[FCM] Unknown notification type: $type');
        break;
    }
  }

  // ════════════════════════════════════════
  // Token Management
  // ════════════════════════════════════════

  /// Handle token dengan retry mechanism.
  /// Jika pertama kali gagal, coba lagi sampai max attempts.
  Future<void> _handleTokenWithRetry() async {
    for (int attempt = 1; attempt <= _tokenRetryMaxAttempts; attempt++) {
      try {
        final token = await _messaging.getToken();
        if (token == null) {
          debugPrint('[FCM] Token null (attempt $attempt/$_tokenRetryMaxAttempts)');
          if (attempt < _tokenRetryMaxAttempts) {
            await Future.delayed(Duration(seconds: 2 * attempt));
            continue;
          }
          return;
        }

        debugPrint('[FCM] Token: ${token.substring(0, 20)}... (attempt $attempt)');
        final success = await _sendTokenToServer(token);
        if (success) {
          debugPrint('[FCM] Token registered successfully on attempt $attempt');
          return;
        }

        // Gagal kirim, retry
        if (attempt < _tokenRetryMaxAttempts) {
          debugPrint('[FCM] Token send failed, retrying in ${2 * attempt}s...');
          await Future.delayed(Duration(seconds: 2 * attempt));
        }
      } catch (e) {
        debugPrint('[FCM] Token error (attempt $attempt): $e');
        if (attempt < _tokenRetryMaxAttempts) {
          await Future.delayed(Duration(seconds: 2 * attempt));
        }
      }
    }
    debugPrint('[FCM] WARNING: Failed to register token after $_tokenRetryMaxAttempts attempts');
  }

  /// Kirim FCM token ke server untuk disimpan di database.
  /// Returns true jika berhasil.
  Future<bool> _sendTokenToServer(String token) async {
    try {
      final authToken = await AuthService.getToken();
      if (authToken.isEmpty) {
        debugPrint('[FCM] No auth token, skip sending FCM token');
        return false;
      }

      // Cek apakah token ini sudah pernah dikirim
      final prefs = await SharedPreferences.getInstance();
      final lastToken = prefs.getString(_lastTokenKey);
      if (lastToken == token && prefs.getBool(_tokenSentKey) == true) {
        debugPrint('[FCM] Token already sent, skip');
        return true; // Sudah pernah berhasil
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/fcm_token.php'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({
          'action': 'register',
          'fcm_token': token,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          await prefs.setString(_lastTokenKey, token);
          await prefs.setBool(_tokenSentKey, true);
          debugPrint('[FCM] Token sent to server successfully');
          return true;
        }
        debugPrint('[FCM] Server returned success=false: ${response.body}');
      } else {
        debugPrint('[FCM] Failed to send token: HTTP ${response.statusCode}');
        debugPrint('[FCM] Response body: ${response.body}');
      }
      return false;
    } catch (e) {
      debugPrint('[FCM] Error sending token to server: $e');
      return false;
    }
  }

  /// Hapus token dari server (dipanggil saat logout).
  Future<void> removeTokenFromServer() async {
    try {
      final authToken = await AuthService.getToken();
      final token = await _messaging.getToken();

      if (authToken.isEmpty || token == null) return;

      await http.post(
        Uri.parse('$_baseUrl/fcm_token.php'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({
          'action': 'unregister',
          'fcm_token': token,
        }),
      );

      // Hapus flag lokal
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenSentKey);
      await prefs.remove(_lastTokenKey);

      debugPrint('[FCM] Token removed from server');
    } catch (e) {
      debugPrint('[FCM] Error removing token: $e');
    }
  }

  // ════════════════════════════════════════
  // Local Notification Channel Setup
  // ════════════════════════════════════════

  Future<void> _setupLocalNotificationChannel() async {
    const androidChannel = AndroidNotificationChannel(
      'fcm_channel',
      'Notifikasi Push',
      description: 'Notifikasi push dari server Sijawara',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    const chatChannel = AndroidNotificationChannel(
      'chat_channel',
      'Pesan Chat',
      description: 'Pesan chat dari diskusi guru & wali',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    const taskChannel = AndroidNotificationChannel(
      'task_channel',
      'Tugas Siswa',
      description: 'Notifikasi saat ananda mengerjakan tugas',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    final androidPlugin =
        _localNotif.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(androidChannel);
    await androidPlugin?.createNotificationChannel(chatChannel);
    await androidPlugin?.createNotificationChannel(taskChannel);
  }

  // ════════════════════════════════════════
  // Helper: Re-register token (setelah login)
  // ════════════════════════════════════════

  /// Dipanggil setelah login berhasil, untuk memastikan
  /// token FCM terdaftar untuk user yang baru login.
  Future<void> registerAfterLogin() async {
    final prefs = await SharedPreferences.getInstance();
    // Reset flag agar token dikirim ulang untuk user baru
    await prefs.remove(_tokenSentKey);
    await _handleTokenWithRetry();
  }
}
