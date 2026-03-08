import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'theme.dart';
import 'pages/home_page.dart';
import 'pages/onboarding_page.dart';
import 'pages/login_page.dart';
import 'pages/wali_home_page.dart';
import 'pages/guru_home_page.dart';
import 'pages/guru_tahfidz_home_page.dart';
import 'services/auth_service.dart';
import 'services/connectivity_service.dart';
import 'services/fcm_service.dart';
import 'widgets/prayer_countdown.dart';
import 'widgets/connectivity_wrapper.dart';

/// Global navigator key – digunakan oleh FcmService untuk navigasi dari notifikasi
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi Firebase
  await Firebase.initializeApp();

  // Register background message handler
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  await initializeDateFormatting('id_ID', null);
  await ConnectivityService.instance.init();

  final prefs = await SharedPreferences.getInstance();
  final hasCompletedOnboarding =
      prefs.getBool('has_completed_initial_onboarding') ?? false;
  final isLoggedIn = prefs.getBool('is_logged_in') ?? false;
  final userRole = prefs.getString('user_role') ?? 'siswa';

  // Inisialisasi FCM jika sudah login
  if (isLoggedIn) {
    await FcmService.instance.init();
  }

  runApp(
    MainApp(
      hasCompletedOnboarding: hasCompletedOnboarding,
      isLoggedIn: isLoggedIn,
      userRole: userRole,
    ),
  );
}

class MainApp extends StatelessWidget {
  final bool hasCompletedOnboarding;
  final bool isLoggedIn;
  final String userRole;

  const MainApp({
    super.key,
    required this.hasCompletedOnboarding,
    required this.isLoggedIn,
    this.userRole = 'siswa',
  });

  @override
  Widget build(BuildContext context) {
    Widget home;
    if (!hasCompletedOnboarding) {
      home = const OnboardingPage();
    } else if (!isLoggedIn) {
      home = const LoginPage();
    } else if (userRole == 'orang_tua') {
      home = const WaliHomePage();
    } else if (userRole == 'guru_tahfidz') {
      home = const GuruTahfidzHomePage();
    } else if (userRole == 'guru_kelas') {
      home = const GuruHomePage();
    } else {
      home = const HomePage();
    }

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Sijawara - Rekap Shalat',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: ConnectivityWrapper(
        child: _LaunchActionGuard(child: home),
      ),
      builder: (context, child) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            FocusManager.instance.primaryFocus?.unfocus();
          },
          child: child,
        );
      },
    );
  }
}

class _LaunchActionGuard extends StatefulWidget {
  final Widget child;

  const _LaunchActionGuard({required this.child});

  @override
  State<_LaunchActionGuard> createState() => _LaunchActionGuardState();
}

class _LaunchActionGuardState extends State<_LaunchActionGuard>
    with WidgetsBindingObserver {
  static const MethodChannel _launchChannel =
      MethodChannel('sijawara/launch_actions');
  bool _isHandlingAction = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPendingLaunchAction();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPendingLaunchAction();
    }
  }

  Future<void> _checkPendingLaunchAction() async {
    if (_isHandlingAction || !mounted) return;

    final action = await _takePendingLaunchAction();
    if (!mounted || action == null || action.isEmpty) return;

    _isHandlingAction = true;
    try {
      switch (action) {
        case 'open_prayer_recap':
          await _handlePrayerRecapLaunch();
          break;
      }
    } finally {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      _isHandlingAction = false;
    }
  }

  Future<String?> _takePendingLaunchAction() async {
    try {
      return await _launchChannel.invokeMethod<String>('getAndClearPendingAction');
    } catch (_) {
      return null;
    }
  }

  Future<void> _handlePrayerRecapLaunch() async {
    final isLoggedIn = await AuthService.isLoggedIn();
    if (!mounted || !isLoggedIn) return;

    final role = await AuthService.getUserRole();
    if (!mounted) return;

    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;

    if (role == 'siswa') {
      // Route melalui HomePage callback agar point animation berfungsi
      final widgetCallback = HomePage.openPrayerRecapFromWidget;
      if (widgetCallback != null) {
        widgetCallback();
      } else {
        showPrayerTrackingSheet(
          context,
          date: DateTime.now(),
          initialEditing: true,
        );
      }
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _StudentOnlySheet(),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _StudentOnlySheet extends StatelessWidget {
  const _StudentOnlySheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.grey200,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_person_rounded,
              color: AppTheme.primaryGreen,
              size: 32,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Widget rekap khusus siswa',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Tombol rekap dari widget hanya bisa dipakai oleh akun siswa untuk membuka rekap ibadah harian.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: AppTheme.grey600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: AppTheme.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: const StadiumBorder(),
              ),
              child: const Text(
                'Mengerti',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
