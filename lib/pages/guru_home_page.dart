import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';
import '../services/auth_service.dart';
import '../services/guru_profile_service.dart';
import '../services/page_cache.dart';
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
  String? _avatarUrl;
  
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

    // Check cache first
    if (PageCache.guruAvatarUrl != null &&
        PageCache.guruName != null &&
        PageCache.isFresh(PageCache.guruTimestamp)) {
      setState(() {
        _userName = PageCache.guruName!;
        _avatarUrl = PageCache.guruAvatarUrl;
      });
      return;
    }

    // Fetch from DB
    try {
      final profile = await GuruProfileService.getBasicProfile();
      if (mounted) {
        setState(() {
          _userName = profile.name.isNotEmpty ? profile.name : _userName;
          _avatarUrl = profile.avatarUrl;
        });
        // Save to cache
        PageCache.guruName = _userName;
        PageCache.guruAvatarUrl = _avatarUrl;
        PageCache.guruTimestamp = DateTime.now();
      }
    } catch (_) {
      // Fallback to SharedPreferences data
    }
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
    PageCache.clearGuru();
    setState(() => _beritaRefreshKey++);
    await _loadUserData();
  }

  void _showBarcodeSheet() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _GuruBarcodeSheet(),
    );
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
                // Refresh avatar/profile data when switching tabs
                // (e.g. after changing avatar in GuruProfilAndaPage)
                _loadUserData();
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
                      avatarUrl: _avatarUrl,
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
          // Barcode icon
          GestureDetector(
            onTap: _showBarcodeSheet,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.grey100,
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.qr_code_scanner_rounded,
                color: AppTheme.primaryGreen,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Logout button
          GestureDetector(
            onTap: _handleLogout,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.grey100,
                  width: 1,
                ),
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

// ═══════════════════════════════════════════════════════
// ───── Bottom Sheet: Guru Barcode (Pindai / Tunjukkan) ─────
// ═══════════════════════════════════════════════════════

class _GuruBarcodeSheet extends StatefulWidget {
  const _GuruBarcodeSheet();

  @override
  State<_GuruBarcodeSheet> createState() => _GuruBarcodeSheetState();
}

class _GuruBarcodeSheetState extends State<_GuruBarcodeSheet>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _scanAnimController;
  late Animation<double> _scanLineAnimation;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _scanAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _scanLineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanAnimController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scanAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewPadding.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.80;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.grey200,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: AppTheme.mainGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.qr_code_scanner_rounded,
                    color: AppTheme.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Absensi Barcode',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Pindai atau tunjukkan kode QR',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.grey400,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.grey100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: AppTheme.grey400,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Tab bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.grey100,
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.all(4),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  gradient: AppTheme.mainGradient,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: AppTheme.greenGlow,
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: AppTheme.white,
                unselectedLabelColor: AppTheme.grey400,
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                tabs: const [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code_scanner_rounded, size: 16),
                        SizedBox(width: 6),
                        Text('Pindai'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code_rounded, size: 16),
                        SizedBox(width: 6),
                        Text('Tunjukkan'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Tab content
          Flexible(
            child: TabBarView(
              controller: _tabController,
              children: [
                // ── Tab 1: Pindai (Scan) ──
                _buildScanTab(),

                // ── Tab 2: Tunjukkan (Show) ──
                _buildShowTab(),
              ],
            ),
          ),

          SizedBox(height: 16 + bottomPad),
        ],
      ),
    );
  }

  Widget _buildScanTab() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            // Camera preview placeholder
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Stack(
                  children: [
                    // Camera placeholder
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.camera_alt_rounded,
                            size: 48,
                            color: Colors.white.withOpacity(0.3),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Kamera akan aktif di sini',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Scan frame corners
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: CustomPaint(
                          painter: _GuruScanFramePainter(),
                        ),
                      ),
                    ),
                    // Animated scan line
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 44,
                          vertical: 44,
                        ),
                        child: AnimatedBuilder(
                          animation: _scanLineAnimation,
                          builder: (context, child) {
                            return Align(
                              alignment: Alignment(
                                0,
                                -1 + 2 * _scanLineAnimation.value,
                              ),
                              child: Container(
                                height: 2,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      AppTheme.primaryGreen.withOpacity(0.8),
                                      AppTheme.emerald,
                                      AppTheme.primaryGreen.withOpacity(0.8),
                                      Colors.transparent,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(1),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.primaryGreen
                                          .withOpacity(0.4),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Instructions
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppTheme.primaryGreen.withOpacity(0.15),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: AppTheme.primaryGreen,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Arahkan kamera ke barcode siswa untuk konfirmasi absensi',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShowTab() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            // QR display placeholder
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.offWhite,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.grey100, width: 1),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: AppTheme.mainGradient,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: AppTheme.greenGlow,
                        ),
                        child: const Icon(
                          Icons.qr_code_rounded,
                          size: 80,
                          color: AppTheme.white,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Kode QR Anda',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tunjukkan ke siswa untuk absensi',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.grey400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Instructions
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.softBlue.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppTheme.softBlue.withOpacity(0.15),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: AppTheme.softBlue,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Siswa dapat memindai kode ini untuk konfirmasi kehadiran',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───── Scan Frame Corner Painter (Guru) ─────
class _GuruScanFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.primaryGreen
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cornerLen = 24.0;

    // Top-left
    canvas.drawLine(const Offset(0, 0), const Offset(cornerLen, 0), paint);
    canvas.drawLine(const Offset(0, 0), const Offset(0, cornerLen), paint);

    // Top-right
    canvas.drawLine(
        Offset(size.width, 0), Offset(size.width - cornerLen, 0), paint);
    canvas.drawLine(
        Offset(size.width, 0), Offset(size.width, cornerLen), paint);

    // Bottom-left
    canvas.drawLine(
        Offset(0, size.height), Offset(cornerLen, size.height), paint);
    canvas.drawLine(
        Offset(0, size.height), Offset(0, size.height - cornerLen), paint);

    // Bottom-right
    canvas.drawLine(Offset(size.width, size.height),
        Offset(size.width - cornerLen, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height),
        Offset(size.width, size.height - cornerLen), paint);
  }

  @override
  bool shouldRepaint(_GuruScanFramePainter oldDelegate) => false;
}
