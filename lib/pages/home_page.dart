import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../theme.dart';
import '../widgets/horizontal_calendar.dart';
import '../widgets/prayer_countdown.dart';
import '../widgets/story_card.dart';
import '../widgets/bottom_menu.dart';
import '../widgets/monthly_calendar.dart';
import '../widgets/point_animation.dart';
import '../widgets/skeleton_loader.dart';
import '../services/prayer_service.dart';
import '../services/auth_service.dart';
import 'quran_page.dart';
import 'profile_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late PageController _pageController; // vertical: calendar/home
  late PageController _horizontalPageController; // horizontal: quran/home
  late ScrollController _scrollController;
  int _currentPage = 1; // vertical: 0 = calendar, 1 = home
  int _horizontalPage = 1; // horizontal: 0 = quran, 1 = home
  int _menuSelectedIndex = 1; // 0 = Al Qur'an, 1 = Beranda, 2 = Profil
  bool _isBottomMenuVisible = true;
  double _lastScrollOffset = 0;
  final GlobalKey _pointTargetKey = GlobalKey();
  int _totalPoints = 0;
  int _streak = 0;
  String _studentName = 'Sahabat Muslim';
  bool _isLoadingData = true;
  bool _isRefreshing = false;
  // Header point counting animation
  AnimationController? _headerCountController;
  Animation<int>? _headerCountAnim;
  bool _isHeaderCounting = false;
  // Keys for refreshing child widgets
  final GlobalKey _calendarKey = GlobalKey();
  final GlobalKey _prayerKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null);
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _fadeController.forward();

    // Start on page 1 (home), page 0 is calendar above
    _pageController = PageController(initialPage: 1);

    // Horizontal: page 0 = quran (left), page 1 = home (center), page 2 = profil (right)
    _horizontalPageController = PageController(initialPage: 1);

    // Scroll controller for hide/show bottom menu
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

    // Load data dari database
    _loadStudentData();
  }

  /// Load data student dari server (poin, streak, nama)
  Future<void> _loadStudentData() async {
    try {
      final isLoggedIn = await AuthService.isLoggedIn();
      if (!isLoggedIn) {
        setState(() => _isLoadingData = false);
        return;
      }

      final data = await PrayerService.getStudentData();
      if (!mounted) return;
      setState(() {
        _totalPoints = data.totalPoints;
        _streak = data.streak;
        _studentName = data.name.isNotEmpty ? data.name : 'Sahabat Muslim';
        _isLoadingData = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingData = false);
      debugPrint('Gagal load student data: $e');
    }
  }

  /// Refresh all data (pull-to-refresh)
  Future<void> _refreshData() async {
    setState(() => _isRefreshing = true);
    
    try {
      // Reload student data
      await _loadStudentData();
      
      // Refresh child widgets (using dynamic cast since states are private)
      (_calendarKey.currentState as dynamic)?.refreshData();
      (_prayerKey.currentState as dynamic)?.refreshData();
      
      if (!mounted) return;
    } catch (e) {
      debugPrint('Gagal refresh data: $e');
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
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

    // Update last offset (clamp to avoid bounce issues)
    if (currentOffset < 0 || currentOffset > maxOffset) {
      _lastScrollOffset = currentOffset.clamp(0, maxOffset);
    } else {
      _lastScrollOffset = currentOffset;
    }
  }

  // Handle scroll from child pages (QuranPage, ProfilePage)
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
    switch (index) {
      case 0: // Al Qur'an → slide to quran page (left)
        _horizontalPageController.animateToPage(
          0,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
        break;
      case 1: // Beranda → slide to home page (right)
        _horizontalPageController.animateToPage(
          1,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
        break;
      case 2: // Profil → slide to profile page (right)
        _horizontalPageController.animateToPage(
          2,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
        break;
    }
  }

  void _onPointsEarned(int earnedPoints) {
    // No-op: animation is now handled by _onPrayerSaved which has bonus info
  }

  /// Callback saat rekap shalat disimpan ke server, refresh data
  void _onPrayerSaved(PrayerSaveResult result) {
    if (!mounted) return;
    final earnedPoints = result.earnedPoints;
    final bonusPoints = result.bonusPoints;
    final wakeUpPoints = result.wakeUpPoints;
    final deedsPoints = result.deedsPoints;
    final comboBonus = result.comboBonus;

    // Update streak immediately
    setState(() => _streak = result.streak);

    if (earnedPoints <= 0) return;

    final oldTotal = _totalPoints;

    // Delay slightly to let bottom sheet close
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      PointAnimationHelper.show(
        context: context,
        earnedPoints: earnedPoints,
        bonusPoints: bonusPoints,
        wakeUpPoints: wakeUpPoints,
        deedsPoints: deedsPoints,
        comboBonus: comboBonus,
        targetKey: _pointTargetKey,
        onShineStart: () {
          if (!mounted) return;
          // Start header counting animation during shine
          _headerCountController?.dispose();
          _headerCountController = AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 800),
          );
          final targetTotal = oldTotal + earnedPoints;
          _headerCountAnim = IntTween(
            begin: oldTotal,
            end: targetTotal,
          ).animate(CurvedAnimation(
            parent: _headerCountController!,
            curve: Curves.easeOutCubic,
          ));
          setState(() => _isHeaderCounting = true);
          _headerCountController!.forward();
          _headerCountController!.addStatusListener((status) {
            if (status == AnimationStatus.completed && mounted) {
              setState(() {
                _totalPoints = targetTotal;
                _isHeaderCounting = false;
              });
            }
          });
        },
        onComplete: () {
          // Points already updated by header count animation
        },
      );
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pageController.dispose();
    _horizontalPageController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _headerCountController?.dispose();
    super.dispose();
  }

  void _toggleCalendar() {
    final target = _currentPage == 1 ? 0 : 1;
    _pageController.animateToPage(
      target,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    );
  }

  /// Tampilkan bottom sheet rincian poin
  void _showPointsBreakdown() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PointsBreakdownSheet(totalPoints: _totalPoints),
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
            // Decorative top background
            _buildTopDecoration(),

            // Horizontal PageView: [0] Quran  [1] Home+Calendar
            PageView(
              controller: _horizontalPageController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              onPageChanged: (page) {
                setState(() {
                  _horizontalPage = page;
                  // 0 = quran, 1 = home, 2 = profil
                  _menuSelectedIndex = page == 0 ? 0 : (page == 2 ? 2 : 1);
                  _isBottomMenuVisible = true;
                });
              },
              children: [
                // ── Horizontal Page 0: Al Qur'an ──
                NotificationListener<ScrollNotification>(
                  onNotification: _handleChildScrollNotification,
                  child: const QuranPage(),
                ),

                // ── Horizontal Page 1: Calendar + Home (vertical) ──
                _buildVerticalPages(),

                // ── Horizontal Page 2: Profil ──
                NotificationListener<ScrollNotification>(
                  onNotification: _handleChildScrollNotification,
                  child: const ProfilePage(),
                ),
              ],
            ),

            // Floating bottom menu (visible on quran page & home page)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                ignoring: !(_horizontalPage == 0 || (_horizontalPage == 1 && _currentPage == 1) || _horizontalPage == 2) || !_isBottomMenuVisible,
                child: BottomMenu(
                  selectedIndex: _menuSelectedIndex,
                  isVisible: (_horizontalPage == 0 || (_horizontalPage == 1 && _currentPage == 1) || _horizontalPage == 2) && _isBottomMenuVisible,
                  onItemTap: _onMenuItemTap,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Vertical Pages (Calendar + Home) ──
  Widget _buildVerticalPages() {
    return PageView(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      physics: const BouncingScrollPhysics(),
      onPageChanged: (page) {
        setState(() {
          _currentPage = page;
          if (page == 1) {
            _menuSelectedIndex = 1;
            _isBottomMenuVisible = true;
          }
        });
      },
      children: [
        _buildCalendarPage(),
        _buildHomePage(),
      ],
    );
  }

  // ── Calendar Page (above) ──
  Widget _buildCalendarPage() {
    return SafeArea(
      child: Column(
        children: [
          // Calendar header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.calendar_month_rounded,
                              size: 16, color: AppTheme.primaryGreen),
                          const SizedBox(width: 6),
                          Text(
                            'Rekap Shalat',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Kalender Bulanan',
                        style:
                            Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                      ),
                    ],
                  ),
                ),
                // Close / back to home button
                GestureDetector(
                  onTap: _toggleCalendar,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: AppTheme.mainGradient,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppTheme.primaryGreen,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Calendar widget
          const Expanded(
            child: MonthlyCalendar(),
          ),

          // Swipe hint
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              children: [
                Icon(Icons.keyboard_arrow_down_rounded,
                    size: 20, color: AppTheme.grey400),
                Text(
                  'Swipe ke bawah untuk kembali',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.grey400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Home Page (main) ──
  Widget _buildHomePage() {
    return SafeArea(
      child: Column(
        children: [
          _buildAppBar(),
          Expanded(
            // Block overscroll from reaching the vertical PageView
            child: NotificationListener<OverscrollNotification>(
              onNotification: (notification) => true,
              child: RefreshIndicator(
                onRefresh: _refreshData,
                color: AppTheme.primaryGreen,
                backgroundColor: AppTheme.white,
                displacement: 40,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: ClampingScrollPhysics(),
                  ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    _isLoadingData
                        ? const HorizontalCalendarSkeleton()
                        : HorizontalCalendar(
                            key: _calendarKey,
                            onDateTap: (date) => showPrayerTrackingSheet(
                              context,
                              date: date,
                              onPointsEarned: _onPointsEarned,
                              onPrayerSaved: _onPrayerSaved,
                            ),
                          ),
                    const SizedBox(height: 16),
                    _isLoadingData
                        ? const PrayerCountdownSkeleton()
                        : PrayerCountdown(
                            key: _prayerKey,
                            onPointsEarned: _onPointsEarned,
                            onPrayerSaved: _onPrayerSaved,
                            streak: _streak,
                          ),
                    const SizedBox(height: 28),
                    _isLoadingData
                        ? const MenuButtonsSkeleton()
                        : const MenuButtonsSection(),
                    const SizedBox(height: 120),
                  ],
                ),
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
                  _studentName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              // Total point
              GestureDetector(
                onTap: _showPointsBreakdown,
                child: Container(
                  key: _pointTargetKey,
                  padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFD97706), Color(0xFFFBBF24)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.stars_rounded,
                        color: Color(0xFFD97706),
                        size: 22,
                      ),
                      const SizedBox(width: 4),
                      _isHeaderCounting && _headerCountAnim != null
                          ? AnimatedBuilder(
                              animation: _headerCountAnim!,
                              builder: (context, _) {
                                return Text(
                                  '${_headerCountAnim!.value}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFFD97706),
                                    height: 1,
                                  ),
                                );
                              },
                            )
                          : Text(
                              '$_totalPoints',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFD97706),
                                height: 1,
                              ),
                            ),
                    ],
                  ),
                ),
              ),
              ), // GestureDetector
              const SizedBox(width: 8),
              // Calendar button
              GestureDetector(
                onTap: _toggleCalendar,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: AppTheme.mainGradient,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.calendar_month_rounded,
                      color: AppTheme.primaryGreen,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// ───── Bottom Sheet: Rincian Poin ─────
// ═══════════════════════════════════════════════════════

class _PointsBreakdownSheet extends StatefulWidget {
  final int totalPoints;
  const _PointsBreakdownSheet({required this.totalPoints});

  @override
  State<_PointsBreakdownSheet> createState() => _PointsBreakdownSheetState();
}

class _PointsBreakdownSheetState extends State<_PointsBreakdownSheet> {
  PointsBreakdown? _breakdown;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBreakdown();
  }

  Future<void> _loadBreakdown() async {
    try {
      final data = await PrayerService.getPointsBreakdown();
      if (!mounted) return;
      setState(() {
        _breakdown = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
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
          const SizedBox(height: 16),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFD97706), Color(0xFFFBBF24)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.stars_rounded,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Rincian Poin',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      'Total: ${widget.totalPoints} poin',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.grey400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Content
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppTheme.primaryGreen,
              ),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Text(
                _error!,
                style: const TextStyle(color: AppTheme.grey400, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            )
          else if (_breakdown != null)
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: Column(
                  children: [
                    // ── Shalat Section ──
                    _buildSectionHeader('Shalat',
                        Icons.mosque_rounded, AppTheme.primaryGreen),
                    const SizedBox(height: 8),
                    _buildBreakdownRow(
                      icon: Icons.person_rounded,
                      label: 'Shalat Sendiri',
                      description: '1 poin per shalat',
                      count: _breakdown!.shalatSendiri.count,
                      points: _breakdown!.shalatSendiri.points,
                      color: AppTheme.emerald,
                    ),
                    _buildBreakdownRow(
                      icon: Icons.groups_rounded,
                      label: "Shalat Jama'ah",
                      description: '2 poin per shalat',
                      count: _breakdown!.shalatJamaah.count,
                      points: _breakdown!.shalatJamaah.points,
                      color: AppTheme.primaryGreen,
                    ),

                    const SizedBox(height: 16),

                    // ── Bonus Section ──
                    _buildSectionHeader('Bonus & Extras',
                        Icons.auto_awesome_rounded, const Color(0xFFEF4444)),
                    const SizedBox(height: 8),
                    _buildBreakdownRow(
                      icon: Icons.emoji_events_rounded,
                      label: 'Bonus 5/5 Shalat',
                      description: '+3 poin saat 5 shalat tercatat',
                      count: _breakdown!.bonus5of5.count,
                      points: _breakdown!.bonus5of5.points,
                      color: const Color(0xFFEF4444),
                      suffix: 'hari',
                    ),
                    _buildBreakdownRow(
                      icon: Icons.alarm_rounded,
                      label: 'Bangun Pagi',
                      description: '+1 poin bangun 03:00/04:00',
                      count: _breakdown!.bangunPagi.count,
                      points: _breakdown!.bangunPagi.points,
                      color: AppTheme.emerald,
                      suffix: 'hari',
                    ),
                    _buildBreakdownRow(
                      icon: Icons.volunteer_activism_rounded,
                      label: 'Amal Kebaikan',
                      description: '+1 poin per amal baik',
                      count: _breakdown!.kebaikan.count,
                      points: _breakdown!.kebaikan.points,
                      color: AppTheme.emerald,
                      suffix: 'amal',
                    ),
                    _buildBreakdownRow(
                      icon: Icons.local_fire_department_rounded,
                      label: 'Combo Bonus',
                      description: '+3 poin saat bangun pagi + kebaikan',
                      count: _breakdown!.comboBonus.count,
                      points: _breakdown!.comboBonus.points,
                      color: const Color(0xFFEF4444),
                      suffix: 'hari',
                    ),

                    if (_breakdown!.publicSpeaking.count > 0) ...[                    
                      const SizedBox(height: 16),
                      _buildSectionHeader('Public Speaking', Icons.record_voice_over_rounded, AppTheme.softPurple),
                      const SizedBox(height: 10),
                      _buildBreakdownRow(
                        icon: Icons.record_voice_over_rounded,
                        label: 'Public Speaking',
                        description: '+2 poin per catatan',
                        count: _breakdown!.publicSpeaking.count,
                        points: _breakdown!.publicSpeaking.points,
                        color: AppTheme.softPurple,
                        suffix: 'catatan',
                      ),
                    ],

                    if (_breakdown!.diskusi.count > 0) ...[
                      const SizedBox(height: 16),
                      _buildSectionHeader('Diskusi', Icons.menu_book_rounded, AppTheme.teal),
                      const SizedBox(height: 10),
                      _buildBreakdownRow(
                        icon: Icons.menu_book_rounded,
                        label: 'Diskusi Keislaman',
                        description: '+2 poin per catatan',
                        count: _breakdown!.diskusi.count,
                        points: _breakdown!.diskusi.points,
                        color: AppTheme.teal,
                        suffix: 'catatan',
                      ),
                    ],

                    const SizedBox(height: 20),
                    // Divider
                    Container(height: 1, color: AppTheme.grey100),
                    const SizedBox(height: 16),

                    // ── Streak ──
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFBBF24).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.whatshot_rounded,
                              size: 18, color: Color(0xFFD97706)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Streak Shalat',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              Text(
                                'Berturut-turut shalat 5 waktu',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.grey400,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFBBF24).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${_breakdown!.streak} hari',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFD97706),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    Container(height: 1, color: AppTheme.grey100),
                    const SizedBox(height: 16),

                    // ── Total ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Poin',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFD97706), Color(0xFFFBBF24)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_breakdown!.totalPoints}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // ── Info box ──
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppTheme.primaryGreen.withOpacity(0.15),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              size: 18, color: AppTheme.primaryGreen),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Kumpulkan poin dengan rajin shalat, bangun pagi, dan beramal baik setiap hari!',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppTheme.primaryGreen.withOpacity(0.8),
                                fontWeight: FontWeight.w500,
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
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(height: 1, color: color.withOpacity(0.15)),
        ),
      ],
    );
  }

  Widget _buildBreakdownRow({
    required IconData icon,
    required String label,
    required String description,
    required int count,
    required int points,
    required Color color,
    String suffix = 'kali',
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  '$description  ·  $count $suffix',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.grey400,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '+$points',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
