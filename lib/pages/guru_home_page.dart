import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';
import '../services/auth_service.dart';
import 'login_page.dart';
import '../widgets/guru_profile_card.dart';
import '../widgets/guru_dashboard_summary.dart';
import '../widgets/guru_fitur_grid.dart';
import '../widgets/guru_bottom_menu.dart';
import '../widgets/wali_guru_input.dart';
import 'guru_siswa_page.dart';
import 'guru_profile_page.dart';
import '../widgets/wali_bottom_menu.dart'; // For BottomMenuScrollHandler

class GuruHomePage extends StatefulWidget {
  const GuruHomePage({super.key});

  @override
  State<GuruHomePage> createState() => _GuruHomePageState();
}

class _GuruHomePageState extends State<GuruHomePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late PageController _horizontalPageController;
  late ScrollController _scrollController;

  String _userName = '';
  String _userRole = '';
  
  int _menuSelectedIndex = 1; // 0 = Siswa, 1 = Beranda, 2 = Profil
  bool _isBottomMenuVisible = true;
  double _lastScrollOffset = 0;
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
    
    _horizontalPageController = PageController(initialPage: 1);
    
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    
    _loadUserData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _horizontalPageController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('user_name') ?? 'Guru';
      _userRole = prefs.getString('user_role') ?? '';
    });
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

  Future<void> _refreshData() async {
    setState(() => _beritaRefreshKey++);
    await _loadUserData();
  }

  String get _roleLabel {
    if (_userRole == 'guru_tahfidz') return 'Guru Tahfidz';
    if (_userRole == 'guru_kelas') return 'Guru Kelas';
    return 'Guru';
  }

  void _onScroll() {
    final currentOffset = _scrollController.offset;
    final maxOffset = _scrollController.position.maxScrollExtent;

    final newVisible = BottomMenuScrollHandler.handleScrollController(
      currentOffset: currentOffset,
      maxOffset: maxOffset,
      lastOffset: _lastScrollOffset,
      isCurrentlyVisible: _isBottomMenuVisible,
    );

    if (newVisible != _isBottomMenuVisible) {
      setState(() => _isBottomMenuVisible = newVisible);
    }

    if (currentOffset < 0 || currentOffset > maxOffset) {
      _lastScrollOffset = currentOffset.clamp(0, maxOffset);
    } else {
      _lastScrollOffset = currentOffset;
    }
  }

  bool _handleChildScrollNotification(ScrollNotification notification) {
    final newVisible = BottomMenuScrollHandler.handleScrollNotification(
      notification,
      isCurrentlyVisible: _isBottomMenuVisible,
    );

    if (newVisible != _isBottomMenuVisible) {
      setState(() => _isBottomMenuVisible = newVisible);
    }
    return false;
  }

  void _onMenuItemTap(int index) {
    setState(() => _menuSelectedIndex = index);
    _horizontalPageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Stack(
          children: [
            _buildTopDecoration(),
            
            PageView(
              controller: _horizontalPageController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              onPageChanged: (page) {
                setState(() {
                  _menuSelectedIndex = page;
                  _isBottomMenuVisible = true;
                });
              },
              children: [
                // ── Page 0: Siswa ──
                NotificationListener<ScrollNotification>(
                  onNotification: _handleChildScrollNotification,
                  child: const GuruSiswaPage(),
                ),

                // ── Page 1: Beranda ──
                _buildDashboard(),

                // ── Page 2: Profil ──
                NotificationListener<ScrollNotification>(
                  onNotification: _handleChildScrollNotification,
                  child: const GuruProfilePage(),
                ),
              ],
            ),

            // Bottom menu
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                ignoring: !_isBottomMenuVisible,
                child: GuruBottomMenu(
                  selectedIndex: _menuSelectedIndex,
                  isVisible: _isBottomMenuVisible,
                  onItemTap: _onMenuItemTap,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    return SafeArea(
      child: Column(
        children: [
          _buildAppBar(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshData,
              color: AppTheme.primaryGreen,
              backgroundColor: AppTheme.white,
              displacement: 40,
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),

                    // Profile Card
                    GuruProfileCard(
                      guruName: _userName,
                      roleLabel: _roleLabel,
                      className: 'Kelas X', // TBD: Ambil dari API
                    ),

                    // Dashboard Summary overlaps the profile card
                    Transform.translate(
                      offset: const Offset(0, -36),
                      child: const GuruDashboardSummary(),
                    ),

                    // Grid Fitur
                    Transform.translate(
                      offset: const Offset(0, -20),
                      child: const GuruFiturGrid(),
                    ),

                    const SizedBox(height: 4),

                    // Berita Sekolah
                    WaliGuruInput(
                      refreshKey: ValueKey(_beritaRefreshKey),
                    ),

                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopDecoration() {
    return Positioned(
      top: -80,
      right: -60,
      child: Container(
        width: 220,
        height: 220,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              AppTheme.emerald.withOpacity(0.12),
              AppTheme.emerald.withOpacity(0.0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    final hour = DateTime.now().hour;
    String greeting;
    IconData greetingIcon;

    if (hour < 12) {
      greeting = 'Selamat Pagi';
      greetingIcon = Icons.wb_sunny_rounded;
    } else if (hour < 15) {
      greeting = 'Selamat Siang';
      greetingIcon = Icons.wb_sunny_rounded;
    } else if (hour < 18) {
      greeting = 'Selamat Sore';
      greetingIcon = Icons.wb_twilight_rounded;
    } else {
      greeting = 'Selamat Malam';
      greetingIcon = Icons.nights_stay_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(greetingIcon, size: 16, color: AppTheme.gold),
                    const SizedBox(width: 6),
                    Text(
                      greeting,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _userName.isNotEmpty ? _userName : 'Dashboard Guru',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Logout button reskinned as a nice circle button 
          GestureDetector(
            onTap: _handleLogout,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.white,
                shape: BoxShape.circle,
                boxShadow: AppTheme.softShadow,
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: Color(0xFFEF4444),
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

