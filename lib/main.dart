import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'theme.dart';
import 'pages/home_page.dart';
import 'pages/onboarding_page.dart';
import 'pages/login_page.dart';
import 'pages/wali_home_page.dart';
import 'pages/guru_home_page.dart';
import 'pages/guru_tahfidz_home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  final prefs = await SharedPreferences.getInstance();
  final hasCompletedOnboarding =
      prefs.getBool('has_completed_initial_onboarding') ?? false;
  final isLoggedIn = prefs.getBool('is_logged_in') ?? false;
  final userRole = prefs.getString('user_role') ?? 'siswa';

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
      title: 'Sijawara - Rekap Shalat',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: home,
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
