import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../services/page_cache.dart';
import 'login_page.dart';
import 'settings/edit_profile_page.dart';
import 'settings/change_password_page.dart';
import 'settings/notification_settings_page.dart';
import 'settings/display_settings_page.dart';
import 'settings/about_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late AnimationController _pointsAnimController;
  late Animation<double> _pointsAnimation;
  late TabController _tabController;
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  // ── State ──
  bool _isLoading = true;
  bool _isLeaderboardLoading = true;
  String? _errorMessage;
  String? _leaderboardError;

  // ── Fallback values ──
  String _studentName = '';
  String _studentClass = '';
  String _schoolName = 'SMA Muhammadiyah Al Kautsar Program Khusus';
  int _totalPoints = 0;
  int _currentLevel = 1;
  int _pointsForNextLevel = 300;
  int _streak = 0;

  List<int> _weeklyPoints = [0, 0, 0, 0, 0, 0, 0];
  List<String> _dayLabels = ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'];
  
  bool _isMonthlyView = false;
  final List<String> _monthLabels = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Ags', 'Sep', 'Okt', 'Nov', 'Des'];
  List<int> _monthlyPoints = List.filled(12, 0);

  List<PointSource> _pointSources = [];
  List<BadgeInfo> _badges = [];
  List<LeaderboardEntry> _leaderboard = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _pointsAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pointsAnimation = CurvedAnimation(
      parent: _pointsAnimController,
      curve: Curves.easeOutCubic,
    );
    
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    
    _shimmerAnimation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );

    _loadProfileData();
    _loadLeaderboardData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pointsAnimController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    // Gunakan cache jika masih segar (30 menit)
    if (PageCache.profileData != null &&
        PageCache.isFresh(PageCache.profileTimestamp)) {
      final cached = PageCache.profileData!;
      if (!mounted) return;
      setState(() {
        _studentName = cached.profile.name;
        _studentClass = cached.profile.className;
        _schoolName = cached.profile.schoolName;
        _totalPoints = cached.profile.totalPoints;
        _currentLevel = cached.profile.currentLevel;
        _pointsForNextLevel = cached.profile.pointsForNextLevel;
        _streak = cached.profile.streak;
        _weeklyPoints = cached.weeklyPoints;
        _dayLabels = cached.dayLabels;
        _monthlyPoints = cached.monthlyPoints;
        _pointSources = cached.pointsBreakdown;
        _badges = cached.badges;
        _isLoading = false;
      });
      _pointsAnimController.forward();
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final data = await ProfileService.getProfile();

      if (!mounted) return;

      // Simpan ke cache
      PageCache.profileData = data;
      PageCache.profileTimestamp = DateTime.now();

      setState(() {
        _studentName = data.profile.name;
        _studentClass = data.profile.className;
        _schoolName = data.profile.schoolName;
        _totalPoints = data.profile.totalPoints;
        _currentLevel = data.profile.currentLevel;
        _pointsForNextLevel = data.profile.pointsForNextLevel;
        _streak = data.profile.streak;

        _weeklyPoints = data.weeklyPoints;
        _dayLabels = data.dayLabels;
        _monthlyPoints = data.monthlyPoints;
        _pointSources = data.pointsBreakdown;
        _badges = data.badges;

        _isLoading = false;
      });

      _pointsAnimController.forward();

      // Tampilkan badge baru jika ada
      if (data.newBadges.isNotEmpty && mounted) {
        _showNewBadgeDialog(data.newBadges);
      }
    } on ProfileServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Terjadi kesalahan: $e';
      });
    }
  }

  Future<void> _loadLeaderboardData() async {
    // Gunakan cache jika masih segar (30 menit)
    if (PageCache.leaderboardData != null &&
        PageCache.isFresh(PageCache.leaderboardTimestamp)) {
      final cached = PageCache.leaderboardData!;
      if (!mounted) return;
      setState(() {
        _leaderboard = cached.leaderboard;
        _isLeaderboardLoading = false;
      });
      return;
    }

    try {
      setState(() {
        _isLeaderboardLoading = true;
        _leaderboardError = null;
      });

      final data = await ProfileService.getLeaderboard();

      if (!mounted) return;

      // Simpan ke cache
      PageCache.leaderboardData = data;
      PageCache.leaderboardTimestamp = DateTime.now();

      setState(() {
        _leaderboard = data.leaderboard;
        _isLeaderboardLoading = false;
      });
    } on ProfileServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLeaderboardLoading = false;
        _leaderboardError = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLeaderboardLoading = false;
        _leaderboardError = 'Terjadi kesalahan: $e';
      });
    }
  }

  /// Pull-to-refresh: hapus cache profil lalu fetch ulang dari server
  Future<void> _refreshProfile() async {
    PageCache.clearProfile();
    _pointsAnimController.reset();
    await _loadProfileData();
  }

  /// Pull-to-refresh leaderboard: hapus cache leaderboard lalu fetch ulang
  Future<void> _refreshLeaderboard() async {
    PageCache.leaderboardData = null;
    PageCache.leaderboardTimestamp = null;
    await _loadLeaderboardData();
  }

  void _showNewBadgeDialog(List<String> badgeNames) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppTheme.cardGradient2,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.military_tech_rounded,
                  color: AppTheme.white, size: 22),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Badge Baru! 🎉',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Selamat! Kamu mendapatkan badge baru:',
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            ...badgeNames.map((name) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.emoji_events_rounded,
                          color: AppTheme.gold, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen.withOpacity(0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Keren! 🎊',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Skeleton UI Helper ──
  Widget _buildShimmerContainer(double width, double height, {double borderRadius = 12}) {
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: AppTheme.white.withOpacity(_shimmerAnimation.value),
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        );
      },
    );
  }
  
  Widget _buildDarkShimmerContainer(double width, double height, {double borderRadius = 12}) {
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: AppTheme.grey200.withOpacity(_shimmerAnimation.value),
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        );
      },
    );
  }

  // Pertahankan state agar tidak di-dispose saat scroll horizontal PageView
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // diperlukan oleh AutomaticKeepAliveClientMixin
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: SafeArea(
        child: NestedScrollView(
          physics: const BouncingScrollPhysics(),
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverToBoxAdapter(child: _buildHeader()),
              SliverToBoxAdapter(child: _buildProfileCard()),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              SliverToBoxAdapter(child: _buildTabBar()),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildPribadiTab(),
              _buildBadgesTab(),
              _buildLeaderboardTab(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ──
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_rounded,
                  size: 14, color: AppTheme.softPurple),
              const SizedBox(width: 6),
              Text(
                'Akun Saya',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Profil Siswa',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
          ),
        ],
      ),
    );
  }

  // ── Tab Bar ──
  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppTheme.grey100,
          borderRadius: BorderRadius.circular(14),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: AppTheme.grey100, width: 1),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: AppTheme.primaryGreen,
          unselectedLabelColor: AppTheme.grey400,
          labelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          labelPadding: EdgeInsets.zero,
          tabs: const [
            Tab(
              height: 40,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_rounded, size: 14),
                  SizedBox(width: 4),
                  Flexible(
                    child: Text('Pribadi', overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
            Tab(
              height: 40,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.military_tech_rounded, size: 14),
                  SizedBox(width: 4),
                  Flexible(
                    child: Text('Badges', overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
            Tab(
              height: 40,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.leaderboard_rounded, size: 14),
                  SizedBox(width: 4),
                  Flexible(
                    child: Text('Ranking', overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Pribadi Tab ──
  Widget _buildPribadiTab() {
    if (_isLoading) {
      return SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              _buildDarkShimmerContainer(double.infinity, 90, borderRadius: 24),
              const SizedBox(height: 16),
              _buildDarkShimmerContainer(double.infinity, 200, borderRadius: 24),
              const SizedBox(height: 16),
              _buildDarkShimmerContainer(double.infinity, 250, borderRadius: 24),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorWidget(_errorMessage!, _loadProfileData);
    }

    return RefreshIndicator(
      color: AppTheme.primaryGreen,
      onRefresh: _refreshProfile,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        child: Column(
          children: [
            const SizedBox(height: 16),
            _buildPointsCard(),
            const SizedBox(height: 16),
            _buildPointsChart(),
            const SizedBox(height: 16),
            _buildSettingsSection(),
            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }

  // ── Badges Tab ──
  Widget _buildBadgesTab() {
    if (_isLoading) {
      return SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildDarkShimmerContainer(120, 24),
                  const Spacer(),
                  _buildDarkShimmerContainer(40, 20),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildDarkShimmerContainer(double.infinity, 100, borderRadius: 16)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildDarkShimmerContainer(double.infinity, 100, borderRadius: 16)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _buildDarkShimmerContainer(double.infinity, 100, borderRadius: 16)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildDarkShimmerContainer(double.infinity, 100, borderRadius: 16)),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorWidget(_errorMessage!, _loadProfileData);
    }

    return RefreshIndicator(
      color: AppTheme.primaryGreen,
      onRefresh: _refreshProfile,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        child: Column(
          children: [
            const SizedBox(height: 16),
            _buildBadgesSection(),
            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }

  // ── Leaderboard Tab ──
  Widget _buildLeaderboardTab() {
    if (_isLeaderboardLoading) {
      return SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildDarkShimmerContainer(80, 120, borderRadius: 16),
                  const SizedBox(width: 10),
                  _buildDarkShimmerContainer(90, 150, borderRadius: 16),
                  const SizedBox(width: 10),
                  _buildDarkShimmerContainer(80, 100, borderRadius: 16),
                ],
              ),
              const SizedBox(height: 24),
              _buildDarkShimmerContainer(double.infinity, 300, borderRadius: 24),
            ],
          ),
        ),
      );
    }

    if (_leaderboardError != null) {
      return _buildErrorWidget(_leaderboardError!, _loadLeaderboardData);
    }

    if (_leaderboard.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 80),
          child: Column(
            children: [
              Icon(Icons.leaderboard_rounded,
                  size: 48, color: AppTheme.grey200),
              const SizedBox(height: 12),
              Text(
                'Belum ada data leaderboard',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.grey400,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final sorted = List<LeaderboardEntry>.from(_leaderboard);

    return RefreshIndicator(
      color: AppTheme.primaryGreen,
      onRefresh: _refreshLeaderboard,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        child: Column(
          children: [
            const SizedBox(height: 16),
            // Top 3 podium
            if (sorted.length >= 3) _buildPodium(sorted),
            const SizedBox(height: 16),
            // Remaining list
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.grey100, width: 1),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: AppTheme.mainGradient,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.format_list_numbered_rounded,
                              color: AppTheme.white,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Peringkat Siswa',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              Text(
                                'Berdasarkan total poin ibadah',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                  color: AppTheme.grey400,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...List.generate(sorted.length, (index) {
                      final entry = sorted[index];
                      final rank = entry.rank > 0 ? entry.rank : index + 1;
                      return _buildLeaderboardItem(entry, rank);
                    }),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget(String message, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 80),
        child: Column(
          children: [
            Icon(Icons.error_outline_rounded,
                size: 48, color: AppTheme.grey400),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.grey400,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
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

  // ── Podium (Top 3) ──
  Widget _buildPodium(List<LeaderboardEntry> sorted) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
        decoration: BoxDecoration(
          gradient: AppTheme.mainGradient,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.grey100, width: 1),
        ),
        child: Column(
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.emoji_events_rounded, color: AppTheme.softGold, size: 20),
                SizedBox(width: 8),
                Text(
                  'Top 3 Siswa Terbaik',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // 2nd place
                Expanded(child: _buildPodiumItem(sorted[1], 2)),
                const SizedBox(width: 8),
                // 1st place
                Expanded(child: _buildPodiumItem(sorted[0], 1)),
                const SizedBox(width: 8),
                // 3rd place
                Expanded(child: _buildPodiumItem(sorted[2], 3)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPodiumItem(LeaderboardEntry entry, int rank) {
    final heights = {1: 100.0, 2: 76.0, 3: 60.0};
    final medalColors = {
      1: const Color(0xFFFFD700),
      2: const Color(0xFFC0C0C0),
      3: const Color(0xFFCD7F32),
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Crown for 1st
        if (rank == 1)
          const Icon(Icons.auto_awesome_rounded, color: AppTheme.softGold, size: 20)
        else
          const SizedBox(height: 20),
        const SizedBox(height: 4),
        // Avatar
        Container(
          width: rank == 1 ? 50 : 42,
          height: rank == 1 ? 50 : 42,
          decoration: BoxDecoration(
            color: AppTheme.white.withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(
              color: medalColors[rank]!,
              width: 2.5,
            ),
          ),
          child: Center(
            child: Text(
              _getInitials(entry.name),
              style: TextStyle(
                fontSize: rank == 1 ? 14 : 12,
                fontWeight: FontWeight.w800,
                color: AppTheme.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          entry.name.split(' ').first,
          style: TextStyle(
            fontSize: 11,
            fontWeight: entry.isMe ? FontWeight.w800 : FontWeight.w600,
            color: entry.isMe ? AppTheme.softGold : AppTheme.white,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          '${entry.totalPoints} poin',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppTheme.white.withOpacity(0.8),
          ),
        ),
        const SizedBox(height: 8),
        // Podium bar
        Container(
          width: double.infinity,
          height: heights[rank],
          decoration: BoxDecoration(
            color: AppTheme.white.withOpacity(0.15),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            border: Border(
              top: BorderSide(color: medalColors[rank]!, width: 3),
            ),
          ),
          child: Center(
            child: Text(
              '#$rank',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: medalColors[rank]!,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Leaderboard Item ──
  Widget _buildLeaderboardItem(LeaderboardEntry entry, int rank) {
    Color? rankColor;
    if (rank == 1) rankColor = const Color(0xFFFFD700);
    if (rank == 2) rankColor = const Color(0xFFC0C0C0);
    if (rank == 3) rankColor = const Color(0xFFCD7F32);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _showStudentBottomSheet(entry, rank);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: entry.isMe ? AppTheme.primaryGreen.withOpacity(0.06) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: entry.isMe
              ? Border.all(color: AppTheme.primaryGreen.withOpacity(0.2), width: 1.5)
              : null,
        ),
        child: Row(
          children: [
            // Rank
            SizedBox(
              width: 28,
              child: rank <= 3
                  ? Icon(Icons.emoji_events_rounded, color: rankColor, size: 20)
                  : Text(
                      '#$rank',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: entry.isMe ? AppTheme.primaryGreen : AppTheme.grey400,
                      ),
                    ),
            ),
            const SizedBox(width: 10),
            // Avatar
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: entry.isMe ? AppTheme.mainGradient : null,
                color: entry.isMe ? null : AppTheme.grey100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  _getInitials(entry.name),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: entry.isMe ? AppTheme.white : AppTheme.grey600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Name & class
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          entry.name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: entry.isMe ? FontWeight.w800 : FontWeight.w600,
                            color: entry.isMe ? AppTheme.primaryGreen : AppTheme.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (entry.isMe) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Kamu',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryGreen,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.className,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: AppTheme.grey400,
                    ),
                  ),
                ],
              ),
            ),
            // Points & streak
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${entry.totalPoints}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: entry.isMe ? AppTheme.primaryGreen : AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.local_fire_department_rounded,
                      size: 12,
                      color: entry.streak >= 7 ? AppTheme.warmOrange : AppTheme.grey400,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${entry.streak} hari',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: entry.streak >= 7 ? AppTheme.warmOrange : AppTheme.grey400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Student Bottom Sheet ──
  void _showStudentBottomSheet(LeaderboardEntry entry, int rank) {
    Color? medalColor;
    if (rank == 1) medalColor = const Color(0xFFFFD700);
    if (rank == 2) medalColor = const Color(0xFFC0C0C0);
    if (rank == 3) medalColor = const Color(0xFFCD7F32);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _StudentDetailSheet(
          entry: entry,
          rank: rank,
          medalColor: medalColor,
          getInitials: _getInitials,
          buildBadgeCard: _buildBadgeCard,
        );
      },
    );
  }

  // ── Profile Card ──
  Widget _buildProfileCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppTheme.mainGradient,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.grey100, width: 1),
        ),
        child: _isLoading
            ? Row(
                children: [
                  _buildShimmerContainer(64, 64, borderRadius: 20),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildShimmerContainer(150, 20),
                        const SizedBox(height: 8),
                        _buildShimmerContainer(100, 14),
                        const SizedBox(height: 6),
                        _buildShimmerContainer(180, 12),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildShimmerContainer(50, 60, borderRadius: 12),
                ],
              )
            : Row(
                children: [
                  // Avatar
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppTheme.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppTheme.white.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: _studentName.isNotEmpty
                          ? Text(
                              _getInitials(_studentName),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.white,
                              ),
                            )
                          : const Icon(
                              Icons.person_rounded,
                              color: AppTheme.white,
                              size: 32,
                            ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _studentName.isNotEmpty ? _studentName : '...',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _studentClass.isNotEmpty ? _studentClass : '...',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.white.withOpacity(0.85),
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

  // ── Points Card (Gamification) ──
  Widget _buildPointsCard() {
    final progress = _pointsForNextLevel > 0
        ? (_totalPoints / _pointsForNextLevel).clamp(0.0, 1.0)
        : 0.0;
    final remaining = max(0, _pointsForNextLevel - _totalPoints);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.grey100, width: 1),
        ),
        child: Column(
          children: [
            // Level & XP header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: AppTheme.cardGradient2,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.emoji_events_rounded,
                        color: AppTheme.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Level Kamu',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        AnimatedBuilder(
                          animation: _pointsAnimation,
                          builder: (context, child) {
                            return Text(
                              '${(_currentLevel * _pointsAnimation.value).toInt()}',
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.textPrimary,
                                letterSpacing: -0.5,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                // Level Badge
              // Container Badge dihapus
              ],
            ),
            const SizedBox(height: 20),
            // Progress bar
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Level $_currentLevel',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    Text(
                      'Level ${_currentLevel + 1}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                AnimatedBuilder(
                  animation: _pointsAnimation,
                  builder: (context, child) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress * _pointsAnimation.value,
                        minHeight: 10,
                        backgroundColor: AppTheme.grey100,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppTheme.primaryGreen,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  '$remaining poin lagi menuju Level ${_currentLevel + 1}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.grey400,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Points Chart ──
  Widget _buildPointsChart() {
    final isMonthly = _isMonthlyView;
    final labels = isMonthly ? _monthLabels : _dayLabels;
    final data = isMonthly ? _monthlyPoints : _weeklyPoints;
    
    final maxVal = data.isEmpty
        ? 1.0
        : data.reduce((a, b) => a > b ? a : b).toDouble();
    final effectiveMax = maxVal > 0 ? maxVal : 1.0;
    
    final title = isMonthly ? 'Poin Bulanan' : 'Poin Mingguan';
    final subtitle = isMonthly ? 'Perolehan poin Januari - Desember' : 'Perolehan poin 7 hari terakhir';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() {
            _isMonthlyView = !_isMonthlyView;
          });
        },
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 600),
          transitionBuilder: (child, animation) {
            return AnimatedBuilder(
              animation: animation,
              builder: (context, childWidget) {
                final blurValue = (1.0 - animation.value) * 10.0;
                return ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: blurValue, sigmaY: blurValue),
                  child: Opacity(
                    opacity: animation.value,
                    child: childWidget,
                  ),
                );
              },
              child: child,
            );
          },
          child: Container(
            key: ValueKey<bool>(_isMonthlyView),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.grey100, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: isMonthly ? AppTheme.cardGradient2 : AppTheme.cardGradient1,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isMonthly ? Icons.calendar_month_rounded : Icons.bar_chart_rounded,
                        color: AppTheme.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              color: AppTheme.grey400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 130,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(
                      min(isMonthly ? 12 : 7, data.length),
                      (index) {
                        final value = data[index];
                        final heightFraction = value / effectiveMax;
                        final isToday = !isMonthly ? index == data.length - 1 : index == DateTime.now().month - 1;

                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: isMonthly ? 2.0 : 4.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  '+$value',
                                  style: TextStyle(
                                    fontSize: isMonthly ? 7.5 : 9,
                                    fontWeight: FontWeight.w700,
                                    color: isToday
                                        ? AppTheme.primaryGreen
                                        : AppTheme.grey400,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.visible,
                                ),
                                const SizedBox(height: 4),
                                AnimatedBuilder(
                                  animation: _pointsAnimation,
                                  builder: (context, child) {
                                    return Container(
                                      height: (90 * heightFraction * _pointsAnimation.value)
                                          .clamp(isMonthly ? 2.0 : 4.0, 90.0),
                                      decoration: BoxDecoration(
                                        gradient: isToday
                                            ? AppTheme.mainGradient
                                            : LinearGradient(
                                                colors: [
                                                  AppTheme.emerald.withOpacity(0.4),
                                                  AppTheme.emerald.withOpacity(0.2),
                                                ],
                                                begin: Alignment.bottomCenter,
                                                end: Alignment.topCenter,
                                              ),
                                        borderRadius: BorderRadius.circular(isMonthly ? 4 : 8),
                                        border: isToday
                                            ? Border.all(color: AppTheme.grey100, width: 1)
                                            : null,
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  index < labels.length
                                      ? labels[index]
                                      : '',
                                  style: TextStyle(
                                    fontSize: isMonthly ? 8.5 : 10,
                                    fontWeight: isToday
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isToday
                                        ? AppTheme.primaryGreen
                                        : AppTheme.grey400,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.visible,
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
      ),
    );
  }

  // ── Badges Section ──
  Widget _buildBadgesSection() {
    final achievedCount = _badges.where((b) => b.isAchieved).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_badges.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'Belum ada badge tersedia',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.grey400,
                  ),
                ),
              ),
            )
          else
            // 2-column grid
            for (int i = 0; i < _badges.length; i += 2)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(child: _buildBadgeCard(_badges[i])),
                    const SizedBox(width: 10),
                    if (i + 1 < _badges.length)
                      Expanded(child: _buildBadgeCard(_badges[i + 1]))
                    else
                      const Expanded(child: SizedBox()),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildBadgeCard(BadgeInfo badge) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.grey100, width: 1),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: badge.isAchieved ? badge.gradient : null,
              color: badge.isAchieved ? null : AppTheme.grey100,
              borderRadius: BorderRadius.circular(14),
              border: badge.isAchieved
                  ? Border.all(color: AppTheme.grey100, width: 1)
                  : null,
            ),
            child: Icon(
              badge.icon,
              color: badge.isAchieved ? AppTheme.white : AppTheme.grey400,
              size: 22,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            badge.name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: badge.isAchieved
                  ? AppTheme.textPrimary
                  : AppTheme.grey400,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            badge.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w400,
              color: badge.isAchieved
                  ? AppTheme.textSecondary
                  : AppTheme.grey400,
            ),
          ),
        ],
      ),
    );
  }

  // ── Settings Section ──
  Widget _buildSettingsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.settings_rounded, size: 18, color: AppTheme.grey600),
              SizedBox(width: 8),
              Text(
                'Pengaturan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Settings Card
          Container(
            decoration: BoxDecoration(
              color: AppTheme.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.grey100, width: 1),
            ),
            child: Column(
              children: [
                _buildSettingItem(
                  icon: Icons.person_outline_rounded,
                  iconColor: AppTheme.primaryGreen,
                  iconBg: AppTheme.primaryGreen.withOpacity(0.1),
                  title: 'Edit Profil',
                  subtitle: 'Ubah nama, foto & info pribadi',
                  onTap: () async {
                    HapticFeedback.lightImpact();
                    final updated = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EditProfilePage(),
                      ),
                    );
                    if (updated == true) _loadProfileData();
                  },
                ),
                _buildDivider(),
                _buildSettingItem(
                  icon: Icons.lock_outline_rounded,
                  iconColor: AppTheme.primaryGreen,
                  iconBg: AppTheme.primaryGreen.withOpacity(0.1),
                  title: 'Ubah Password',
                  subtitle: 'Ganti kata sandi akun',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ChangePasswordPage(),
                      ),
                    );
                  },
                ),
                _buildDivider(),
                _buildSettingItem(
                  icon: Icons.notifications_none_rounded,
                  iconColor: AppTheme.primaryGreen,
                  iconBg: AppTheme.primaryGreen.withOpacity(0.1),
                  title: 'Notifikasi',
                  subtitle: 'Atur pengingat shalat & ibadah',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NotificationSettingsPage(),
                      ),
                    );
                  },
                ),

                _buildDivider(),
                _buildSettingItem(
                  icon: Icons.info_outline_rounded,
                  iconColor: AppTheme.primaryGreen,
                  iconBg: AppTheme.primaryGreen.withOpacity(0.1),
                  title: 'Tentang Aplikasi',
                  subtitle: 'Versi 1.0.0',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AboutPage(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Logout Button
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              _showLogoutDialog();
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.grey100, width: 1),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.logout_rounded,
                    color: Color(0xFFEF4444),
                    size: 20,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Keluar dari Akun',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFEF4444),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: AppTheme.grey400,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.grey400,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(height: 1, color: AppTheme.grey100),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 22),
            SizedBox(width: 10),
            Text(
              'Keluar',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        content: const Text(
          'Apakah kamu yakin ingin keluar dari akun?',
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Batal',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.grey400,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await AuthService.logout();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
              );
            },
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444).withOpacity(0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Ya, Keluar',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFFEF4444),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Helper: ambil inisial dari nama
  String _getInitials(String name) {
    return name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join();
  }
}

// ═══════════════════════════════════════
// Student Detail Bottom Sheet (Stateful - loads badges from API)
// ═══════════════════════════════════════

class _StudentDetailSheet extends StatefulWidget {
  final LeaderboardEntry entry;
  final int rank;
  final Color? medalColor;
  final String Function(String) getInitials;
  final Widget Function(BadgeInfo) buildBadgeCard;

  const _StudentDetailSheet({
    required this.entry,
    required this.rank,
    this.medalColor,
    required this.getInitials,
    required this.buildBadgeCard,
  });

  @override
  State<_StudentDetailSheet> createState() => _StudentDetailSheetState();
}

class _StudentDetailSheetState extends State<_StudentDetailSheet> {
  StudentDetail? _detail;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    final detail =
        await ProfileService.getStudentDetail(widget.entry.studentId);
    if (!mounted) return;
    setState(() {
      _detail = detail;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.4,
      maxChildSize: 1,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.bgColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.zero,
            children: [
              // Handle bar
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 20),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.grey200,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Profile section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: AppTheme.mainGradient,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.grey100, width: 1),
                  ),
                  child: Column(
                    children: [
                      // Avatar
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppTheme.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: widget.medalColor ??
                                AppTheme.white.withOpacity(0.3),
                            width: 3,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            widget.getInitials(widget.entry.name),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Name
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              widget.entry.name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.white,
                                letterSpacing: -0.3,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (widget.entry.isMe) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Kamu',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.entry.className,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.white.withOpacity(0.8),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Stats row
                      Row(
                        children: [
                          Expanded(
                            child: _buildStat(
                              icon: Icons.emoji_events_rounded,
                              label: 'Peringkat',
                              value: '#${widget.rank}',
                              color: widget.medalColor,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildStat(
                              icon: Icons.star_rounded,
                              label: 'Total Poin',
                              value: '${widget.entry.totalPoints}',
                              color: null,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildStat(
                              icon: Icons.local_fire_department_rounded,
                              label: 'Streak',
                              value: '${widget.entry.streak} hari',
                              color: widget.entry.streak >= 7
                                  ? AppTheme.warmOrange
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Badges
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(
                    child: CircularProgressIndicator(
                        color: AppTheme.primaryGreen),
                  ),
                )
              else if (_detail != null)
                Builder(builder: (context) {
                  final activeBadges = _detail!.badges.where((b) => b.isAchieved).toList();
                  if (activeBadges.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.grey100, width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.military_tech_rounded,
                                  size: 18, color: AppTheme.gold),
                              const SizedBox(width: 8),
                              const Text(
                                'Pencapaian',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${activeBadges.length} badge',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.grey400,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          for (int i = 0; i < activeBadges.length; i += 2)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                children: [
                                  Expanded(
                                      child: widget.buildBadgeCard(activeBadges[i])),
                                  const SizedBox(width: 10),
                                  if (i + 1 < activeBadges.length)
                                    Expanded(
                                        child: widget.buildBadgeCard(activeBadges[i + 1]))
                                  else
                                    const Expanded(child: SizedBox()),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 16),
              const SizedBox(height: 70),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStat({
    required IconData icon,
    required String label,
    required String value,
    Color? color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, color: color ?? AppTheme.softGold, size: 18),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppTheme.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AppTheme.white.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}
