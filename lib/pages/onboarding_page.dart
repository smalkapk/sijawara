import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';
import 'login_page.dart';

/// Onboarding Page - Shows only once after first install
/// Page 1: Welcome with image
/// Page 2: Permission requests (notification & precise location)
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Permission states
  bool _notificationGranted = false;
  bool _locationGranted = false;
  bool _isPreciseLocation = false;
  bool _isRequestingPermission = false;

  @override
  void initState() {
    super.initState();
    _checkCurrentPermissions();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Check current permission status
  Future<void> _checkCurrentPermissions() async {
    final notifStatus = await Permission.notification.status;
    final locationStatus = await Permission.locationWhenInUse.status;

    setState(() {
      _notificationGranted = notifStatus.isGranted;
      _locationGranted = locationStatus.isGranted;
    });

    if (_locationGranted) {
      await _checkPreciseLocation();
    }
  }

  /// Check if precise location is enabled
  Future<void> _checkPreciseLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      setState(() {
        _isPreciseLocation = position.accuracy < 100;
      });
    } catch (e) {
      debugPrint('Error checking location precision: $e');
      setState(() {
        _isPreciseLocation = false;
      });
    }
  }

  /// Request notification permission
  Future<void> _requestNotificationPermission() async {
    if (_isRequestingPermission) return;

    setState(() => _isRequestingPermission = true);

    try {
      final status = await Permission.notification.request();
      setState(() {
        _notificationGranted = status.isGranted;
      });
    } finally {
      setState(() => _isRequestingPermission = false);
    }
  }

  /// Show bottom sheet explaining location permission
  void _showLocationPermissionBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            // Icon
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.location_on_rounded,
                size: 36,
                color: AppTheme.primaryGreen,
              ),
            ),
            const SizedBox(height: 20),

            // Title
            const Text(
              'Lokasi Presisi Dibutuhkan',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            // Description
            const Text(
              'Untuk memastikan fitur lokasi berjalan dengan akurat, kami memerlukan akses lokasi presisi (tepat) dari perangkat Anda.\n\nPastikan untuk mengaktifkan "Lokasi Presisi" atau "Precise Location" saat diminta.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 24),

            // Request permission button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _requestLocationPermission();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Izinkan Lokasi Presisi',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  /// Request location permission with precise location enforcement
  Future<void> _requestLocationPermission() async {
    if (_isRequestingPermission) return;

    setState(() => _isRequestingPermission = true);

    try {
      final status = await Permission.locationWhenInUse.request();

      if (status.isGranted) {
        setState(() => _locationGranted = true);

        await _checkPreciseLocation();

        if (!_isPreciseLocation && mounted) {
          await _showPreciseLocationDialog();
        }
      } else if (status.isPermanentlyDenied) {
        if (mounted) {
          await _showPermissionDeniedDialog('Lokasi');
        }
      }
    } finally {
      setState(() => _isRequestingPermission = false);
    }
  }

  /// Show dialog explaining why precise location is needed
  Future<void> _showPreciseLocationDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.location_on, color: Colors.orange.shade600),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Lokasi Presisi Diperlukan',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        content: const Text(
          'Untuk memastikan fitur lokasi berjalan dengan akurat, aplikasi memerlukan izin lokasi presisi (tepat).\n\nMohon aktifkan "Lokasi Presisi" atau "Precise Location" di pengaturan aplikasi.',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Buka Pengaturan'),
          ),
        ],
      ),
    );

    if (result == true) {
      await Geolocator.openLocationSettings();
      await Future.delayed(const Duration(seconds: 1));
      await _checkPreciseLocation();
    }
  }

  /// Show dialog for permanently denied permission
  Future<void> _showPermissionDeniedDialog(String permissionName) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Izin $permissionName Ditolak'),
        content: Text(
          'Izin $permissionName diperlukan untuk aplikasi ini. '
          'Mohon aktifkan di pengaturan aplikasi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Buka Pengaturan'),
          ),
        ],
      ),
    );
  }

  /// Complete onboarding and navigate to login page
  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_completed_initial_onboarding', true);

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  /// Go to next page
  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (index) => setState(() => _currentPage = index),
        children: [_buildWelcomePage(), _buildPermissionsPage()],
      ),
    );
  }

  Widget _buildPageIndicator(int index, {bool isWhite = false}) {
    final isActive = _currentPage == index;
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 4,
        decoration: BoxDecoration(
          color: isWhite
              ? (isActive ? Colors.white : Colors.white.withValues(alpha: 0.4))
              : (isActive ? AppTheme.primaryGreen : AppTheme.grey200),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  /// Page 1: Welcome Page
  Widget _buildWelcomePage() {
    return Stack(
      children: [
        // Background Image
        Positioned.fill(
          child: Image.asset(
            'lib/assets/bg-onboarding.png',
            fit: BoxFit.cover,
          ),
        ),

        // Gradient overlay - green tone
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.transparent,
                  AppTheme.darkGreen.withValues(alpha: 0.7),
                  AppTheme.darkGreen.withValues(alpha: 0.95),
                ],
                stops: const [0.0, 0.4, 0.7, 1.0],
              ),
            ),
          ),
        ),

        // Page indicator
        Positioned(
          top: MediaQuery.of(context).padding.top + 16,
          left: 24,
          right: 24,
          child: Row(
            children: [
              _buildPageIndicator(0, isWhite: true),
              const SizedBox(width: 8),
              _buildPageIndicator(1, isWhite: true),
            ],
          ),
        ),

        // Content at bottom
        Positioned(
          left: 24,
          right: 24,
          bottom: 40,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Digitalisasi Dimulai\nDari Sekarang',
                textAlign: TextAlign.left,
                style: TextStyle(
                  fontSize: 33,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Catat, rekap, dan pantau seluruh aktivitas SMALKA dalam satu aplikasi',
                textAlign: TextAlign.left,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white.withValues(alpha: 0.9),
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 32),
              // Continue button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _nextPage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.darkGreen,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Lanjutkan',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 35),
            ],
          ),
        ),
      ],
    );
  }

  /// Page 2: Permissions Page
  Widget _buildPermissionsPage() {
    // TODO: Dummy mode - always allow to proceed. Remove this when permissions are properly implemented.
    const bool isDummyMode = true;
    final allPermissionsGranted = isDummyMode || (_notificationGranted && _locationGranted);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page indicator
            Row(
              children: [
                _buildPageIndicator(0),
                const SizedBox(width: 8),
                _buildPageIndicator(1),
              ],
            ),
            const SizedBox(height: 24),

            // Title
            const Text(
              'Perizinan Aplikasi',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Untuk melanjutkan silahkan berikan kami perizinan sebagai mana berikut:',
              style: TextStyle(
                fontSize: 15,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 32),

            // Permission Cards
            _buildPermissionCard(
              icon: Icons.notifications_rounded,
              iconColor: AppTheme.gold,
              iconBgColor: AppTheme.softGold.withValues(alpha: 0.3),
              title: 'Notifikasi',
              description:
                  'Untuk menerima pengingat waktu shalat dan rekap harian',
              isGranted: _notificationGranted,
              onTap: _requestNotificationPermission,
            ),

            const SizedBox(height: 16),

            _buildPermissionCard(
              icon: Icons.location_on_rounded,
              iconColor: AppTheme.primaryGreen,
              iconBgColor: AppTheme.mint.withValues(alpha: 0.4),
              title: 'Lokasi Presisi',
              description: _isPreciseLocation
                  ? 'Lokasi presisi aktif untuk jadwal shalat yang akurat'
                  : 'Untuk menentukan jadwal shalat sesuai lokasi Anda',
              isGranted: _locationGranted,
              showPreciseWarning: _locationGranted && !_isPreciseLocation,
              onTap: _showLocationPermissionBottomSheet,
            ),

            const Spacer(),

            // Info text
            if (!isDummyMode && !allPermissionsGranted)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.grey100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: AppTheme.grey400,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Tap pada kartu di atas untuk memberikan izin yang diperlukan.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.grey600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // Buttons row
            Row(
              children: [
                // Back button
                Expanded(
                  flex: 1,
                  child: OutlinedButton(
                    onPressed: () {
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutCubic,
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                      side: const BorderSide(color: AppTheme.grey200),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Kembali',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // Continue/Start button
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed:
                        allPermissionsGranted ? _completeOnboarding : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppTheme.grey200,
                      disabledForegroundColor: AppTheme.grey400,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      allPermissionsGranted ? 'Mulai' : 'Berikan Izin',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String description,
    required bool isGranted,
    bool showPreciseWarning = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: _isRequestingPermission ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isGranted
              ? AppTheme.mint.withValues(alpha: 0.2)
              : AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isGranted
                ? (showPreciseWarning
                      ? Colors.orange.shade200
                      : AppTheme.emerald.withValues(alpha: 0.5))
                : AppTheme.grey200,
            width: isGranted ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isGranted
                    ? AppTheme.emerald.withValues(alpha: 0.3)
                    : iconBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isGranted ? Icons.check_rounded : icon,
                color: isGranted ? AppTheme.deepGreen : iconColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),

            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      if (isGranted) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: showPreciseWarning
                                ? Colors.orange.shade100
                                : AppTheme.mint.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            showPreciseWarning ? 'Tidak Presisi' : 'Diizinkan',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: showPreciseWarning
                                  ? Colors.orange.shade700
                                  : AppTheme.deepGreen,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            // Arrow or loading
            if (_isRequestingPermission)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.primaryGreen,
                ),
              )
            else if (!isGranted)
              const Icon(Icons.chevron_right, color: AppTheme.grey400)
            else if (showPreciseWarning)
              Icon(
                Icons.warning_rounded,
                color: Colors.orange.shade600,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
