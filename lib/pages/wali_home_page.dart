import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/wali_service.dart';
import '../widgets/wali_bottom_menu.dart';
import '../widgets/wali_student_profile.dart';
import '../widgets/wali_ibadah_status.dart';
import '../widgets/wali_guru_input.dart';
import '../widgets/wali_fitur_grid.dart';
import '../widgets/wali_maklumat_widget.dart';
import 'wali_live_page.dart';
import 'wali_profile_page.dart';
import '../widgets/skeleton_loader.dart';

class WaliHomePage extends StatefulWidget {
  const WaliHomePage({super.key});

  @override
  State<WaliHomePage> createState() => _WaliHomePageState();
}

class _WaliHomePageState extends State<WaliHomePage>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late PageController _horizontalPageController;
  late ScrollController _scrollController;

  int _menuSelectedIndex = 1; // 0 = Live, 1 = Beranda, 2 = Profil
  bool _isBottomMenuVisible = true;
  double _lastScrollOffset = 0;

  // ── State data dari API ──
  WaliDashboardData? _dashboardData;
  bool _isLoading = true;
  String? _errorMessage;
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

    // Load data dari API
    _loadDashboard();
  }

  Future<void> _loadDashboard({int? studentId}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await WaliService.getDashboard(studentId: studentId);
      if (mounted) {
        setState(() {
          _dashboardData = data;
          _isLoading = false;
        });
      }
    } on WaliServiceException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Terjadi kesalahan: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshData() async {
    setState(() => _beritaRefreshKey++);
    await _loadDashboard(
      studentId: _dashboardData?.selectedChild?.studentId,
    );
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
  void dispose() {
    _fadeController.dispose();
    _horizontalPageController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
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
                // ── Page 0: Live Data Siswa ──
                NotificationListener<ScrollNotification>(
                  onNotification: _handleChildScrollNotification,
                  child: WaliLivePage(
                    studentId: _dashboardData?.selectedChild?.studentId,
                  ),
                ),

                // ── Page 1: Beranda Wali ──
                _buildDashboard(),

                // ── Page 2: Profil Wali ──
                NotificationListener<ScrollNotification>(
                  onNotification: _handleChildScrollNotification,
                  child: WaliProfilePage(
                    dashboardData: _dashboardData,
                  ),
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
                child: WaliBottomMenu(
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
              child: _isLoading
                  ? _buildLoadingState()
                  : _errorMessage != null
                      ? _buildErrorState()
                      : SingleChildScrollView(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),

                              // Student Profile Card (tap untuk ganti anak)
                              WaliStudentProfile(
                                child: _dashboardData?.selectedChild,
                                allChildren: _dashboardData?.children ?? [],
                                onChildSwitch: (studentId) {
                                  _loadDashboard(studentId: studentId);
                                },
                              ),

                              // Ibadah Status overlaps the profile card
                              Transform.translate(
                                offset: const Offset(0, -36),
                                child: WaliIbadahStatus(
                                  prayers: _dashboardData?.todayPrayers ?? [],
                                  extras: _dashboardData?.todayExtras,
                                  summary: _dashboardData?.todaySummary,
                                  studentName:
                                      _dashboardData?.selectedChild?.studentName ??
                                          '',
                                  studentId:
                                      _dashboardData?.selectedChild?.studentId ??
                                          0,
                                ),
                              ),

                              // Grid Fitur
                              Transform.translate(
                                offset: const Offset(0, -20),
                                child: Column(
                                  children: [
                                    const WaliMaklumatWidget(),
                                    const SizedBox(height: 16),
                                    WaliFiturGrid(
                                      studentId: _dashboardData?.selectedChild?.studentId,
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 4),

                              // Berita Sekolah
                              WaliGuruInput(
                                refreshKey: ValueKey(_beritaRefreshKey),
                              ),

                              const SizedBox(height: 4),

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

  Widget _buildLoadingState() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),

          // Skeleton Student Profile Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SkeletonLoader(
              height: 140,
              width: double.infinity,
              borderRadius: BorderRadius.circular(20),
            ),
          ),

          // Skeleton Ibadah Status
          Transform.translate(
            offset: const Offset(0, -36),
            child: const PrayerCountdownSkeleton(),
          ),

          // Skeleton Fitur Grid
          Transform.translate(
            offset: const Offset(0, -20),
            child: const MenuButtonsSkeleton(),
          ),

          // Skeleton Guru Input Berita dsb
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLoader(
                  height: 24,
                  width: 140,
                  borderRadius: BorderRadius.circular(8),
                ),
                const SizedBox(height: 16),
                SkeletonLoader(
                  height: 160,
                  width: double.infinity,
                  borderRadius: BorderRadius.circular(24),
                ),
                const SizedBox(height: 16),
                SkeletonLoader(
                  height: 160,
                  width: double.infinity,
                  borderRadius: BorderRadius.circular(24),
                ),
              ],
            ),
          ),

          const SizedBox(height: 120),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 56,
              color: AppTheme.grey400,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Terjadi kesalahan',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _refreshData,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: AppTheme.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
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
                  _dashboardData?.parent.name.isNotEmpty == true
                      ? '${_dashboardData!.parent.name}'
                      : 'Dashboard Orang Tua',
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
          // Notification bell - Minimalist design
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.white,
              shape: BoxShape.circle,
              boxShadow: AppTheme.softShadow,
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              color: AppTheme.primaryGreen,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }
}
