import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';
import '../services/auth_service.dart';
import 'login_page.dart';
import '../widgets/wali_guru_input.dart';
import 'guru_tahfidz_quran.dart';
import 'guru_tahfidz_nilai_kelas_page.dart';

class GuruTahfidzHomePage extends StatefulWidget {
  const GuruTahfidzHomePage({super.key});

  @override
  State<GuruTahfidzHomePage> createState() => _GuruTahfidzHomePageState();
}

class _GuruTahfidzHomePageState extends State<GuruTahfidzHomePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  String _userName = '';
  String _userAvatarUrl = '';
  int _beritaRefreshKey = 0;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _fadeController.forward();
    _loadUserData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('user_name') ?? 'Guru Tahfidz';
      _userAvatarUrl = prefs.getString('avatar_url') ?? '';
    });
  }

  Future<void> _refreshData() async {
    setState(() => _beritaRefreshKey++);
    await _loadUserData();
  }

  Future<void> _handleLogout() async {
    await AuthService.logout();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Memakai warna background putih lembut (off-white) agar mirip contoh UI
    final bgColor = const Color(0xFFF9FAFB);

    return Scaffold(
      backgroundColor: bgColor,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopBar(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refreshData,
                  color: AppTheme.primaryGreen,
                  backgroundColor: AppTheme.white,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: _buildHeader(),
                        ),
                        const SizedBox(height: 32),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: _buildMenuGrid(),
                        ),
                        const SizedBox(height: 24),
                        // Berita Sekolah
                        WaliGuruInput(
                          refreshKey: ValueKey(_beritaRefreshKey),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left Profile Image (Replaces Grid Logo)
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.5), width: 2),
            ),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: AppTheme.white,
              backgroundImage: _userAvatarUrl.isNotEmpty
                  ? NetworkImage(_userAvatarUrl)
                  : const AssetImage('lib/assets/default_avatar.png') as ImageProvider,
              onBackgroundImageError: (_, __) {},
              child: _userAvatarUrl.isEmpty
                  ? const Icon(Icons.person_outline, color: AppTheme.textSecondary)
                  : null,
            ),
          ),
          
          // Right action (Logout like a Search button in the example UI)
          GestureDetector(
            onTap: _handleLogout,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: AppTheme.textPrimary,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w400,
              color: AppTheme.textPrimary,
              height: 1.15,
            ),
            children: [
              const TextSpan(text: 'Assalamualaikum,\n'),
              TextSpan(
                text: _userName.isNotEmpty ? _userName : 'Guru',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMenuGrid() {
    return Container(
      padding: const EdgeInsets.all(20),
      // No horizontal margin here since we already have 24 horizontal padding in SingleChildScrollView
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.cardShadow,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const double spacing = 12.0;
          final double itemWidth = (constraints.maxWidth - (spacing * 3)) / 4;

          Widget buildGridItem(
            String title,
            IconData icon,
            Color color, {
            VoidCallback? onTap,
          }) {
            return SizedBox(
              width: itemWidth,
              child: _buildFiturItem(context, title, icon, color, onTap),
            );
          }

          return Wrap(
            alignment: WrapAlignment.center,
            spacing: spacing,
            runSpacing: 16.0,
            children: [
              buildGridItem(
                "Al Qur'an",
                Icons.menu_book_rounded,
                AppTheme.primaryGreen,
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const GuruTahfidzQuran(),
                    ),
                  );
                },
              ),
              buildGridItem(
                "Nilai Siswa",
                Icons.assignment_rounded,
                AppTheme.gold,
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const GuruTahfidzNilaiKelasPage(),
                    ),
                  );
                },
              ),
              buildGridItem(
                "ALKA AI",
                Icons.auto_awesome_rounded,
                AppTheme.primaryGreen,
                onTap: () {
                  HapticFeedback.lightImpact();
                  _showNotAvail("ALKA AI");
                },
              ),
              buildGridItem(
                "Profile",
                Icons.person_rounded,
                AppTheme.softBlue,
                onTap: () {
                  HapticFeedback.lightImpact();
                  _showNotAvail("Profile");
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFiturItem(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback? onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 10,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }



  void _showNotAvail(String menu) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Menu $menu belum tersedia')),
    );
  }
}
