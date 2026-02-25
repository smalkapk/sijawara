import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import '../theme.dart';
import '../services/wali_service.dart';

/// Kalender bulanan rekap shalat untuk Wali (Read-Only).
/// Desain modern dengan gradient header, stats cards, dan heatmap grid.
class WaliMonthlyCalendar extends StatefulWidget {
  final String studentName;
  final int studentId;

  const WaliMonthlyCalendar({
    super.key,
    this.studentName = '',
    required this.studentId,
  });

  @override
  State<WaliMonthlyCalendar> createState() => _WaliMonthlyCalendarState();
}

class _WaliMonthlyCalendarState extends State<WaliMonthlyCalendar>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late DateTime _currentMonth;
  late AnimationController _fadeController;

  static const int _totalPages = 120;
  static const int _centrePage = 60;

  // Data dari API — key: "YYYY-MM" → heatmap & stats
  final Map<String, WaliMonthlyCalendarData> _monthCache = {};
  final Set<String> _loadingMonths = {};

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null);
    _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
    _pageController = PageController(initialPage: _centrePage);
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();

    // Load bulan ini
    _loadMonthData(_currentMonth);
  }

  DateTime _monthFromPage(int page) {
    final diff = page - _centrePage;
    return DateTime(_currentMonth.year, _currentMonth.month + diff);
  }

  String _monthKey(DateTime month) =>
      '${month.year}-${month.month.toString().padLeft(2, '0')}';

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Load data bulan dari API (dengan cache)
  Future<void> _loadMonthData(DateTime month) async {
    final key = _monthKey(month);
    if (_monthCache.containsKey(key) || _loadingMonths.contains(key)) return;

    _loadingMonths.add(key);
    if (mounted) setState(() {});

    try {
      final data = await WaliService.getMonthlyCalendar(
        studentId: widget.studentId,
        month: key,
      );
      _monthCache[key] = data;
    } catch (_) {
      // Jika gagal, tetap hapus dari loading agar tidak retry terus-menerus
    } finally {
      _loadingMonths.remove(key);
      if (mounted) setState(() {});
    }
  }

  /// Load detail hari dan tampilkan bottom sheet
  Future<void> _loadAndShowDayDetail(
      BuildContext context, DateTime date) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryGreen),
      ),
    );

    try {
      final detail = await WaliService.getDayDetail(
        studentId: widget.studentId,
        date: _dateKey(date),
      );
      if (mounted) {
        Navigator.pop(context); // dismiss loading
        _showDayDetailSheet(context, date, detail);
      }
    } on WaliServiceException catch (e) {
      if (mounted) {
        Navigator.pop(context); // dismiss loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }
  }

  int _getCurrentPage() {
    if (_pageController.hasClients) {
      return _pageController.page?.round() ?? _centrePage;
    }
    return _centrePage;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: FadeTransition(
        opacity: CurvedAnimation(
          parent: _fadeController,
          curve: Curves.easeOutCubic,
        ),
        child: Column(
          children: [
            // ── Custom Gradient AppBar ──
            _buildGradientAppBar(),

            // ── Content ──
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 20, bottom: 60),
                child: _buildCalendarCard(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // ───── Custom Gradient AppBar ──────────────────────
  // ═══════════════════════════════════════════════════

  Widget _buildGradientAppBar() {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.bgColor, // Matches the scaffold background
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 20, 20),
          child: Row(
            children: [
              // Back button
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: AppTheme.textPrimary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 4),
              // Title area
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Rekap Bulanan',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),

                    Row(
                      children: [
                        Text(
                          widget.studentName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // ───── Calendar Card ──────────────────────────────
  // ═══════════════════════════════════════════════════

  Widget _buildCalendarCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: AppTheme.softShadow,
        ),
        child: Column(
          children: [
            _buildMonthHeader(),
            _buildDayLabels(),
            const SizedBox(height: 4),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                itemCount: _totalPages,
                onPageChanged: (page) {
                  final month = _monthFromPage(page);
                  _loadMonthData(month);
                  setState(() {});
                },
                itemBuilder: (context, page) {
                  final month = _monthFromPage(page);
                  return _buildMonthGrid(month);
                },
              ),
            ),
            _buildLegend(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthHeader() {
    return AnimatedBuilder(
      animation: _pageController,
      builder: (context, _) {
        final page = _getCurrentPage();
        final month = _monthFromPage(page);
        final monthName = DateFormat('MMMM yyyy', 'id_ID').format(month);
        final key = _monthKey(month);
        final isLoading = _loadingMonths.contains(key);

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppTheme.mainGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.calendar_today_rounded,
                  color: AppTheme.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    Text(
                      monthName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (isLoading) ...[
                      const SizedBox(width: 8),
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Navigation
              Row(
                children: [
                  _buildNavButton(
                    icon: Icons.chevron_left_rounded,
                    onTap: () {
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                      );
                    },
                  ),
                  const SizedBox(width: 4),
                  _buildNavButton(
                    icon: Icons.chevron_right_rounded,
                    onTap: () {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppTheme.primaryGreen.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 20, color: AppTheme.primaryGreen),
      ),
    );
  }

  Widget _buildDayLabels() {
    const days = ['MIN', 'SEN', 'SEL', 'RAB', 'KAM', 'JUM', 'SAB'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: days.map((d) {
          final isFriday = d == 'JUM';
          return Expanded(
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                decoration: isFriday
                    ? BoxDecoration(
                        color: AppTheme.primaryGreen.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                      )
                    : null,
                child: Text(
                  d,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isFriday ? AppTheme.primaryGreen : AppTheme.grey400,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // ───── Month Grid (Heatmap) ───────────────────────
  // ═══════════════════════════════════════════════════

  Widget _buildMonthGrid(DateTime month) {
    final today = DateTime.now();
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final firstWeekday = DateTime(month.year, month.month, 1).weekday % 7;

    final key = _monthKey(month);
    final calendarData = _monthCache[key];
    final heatmap = calendarData?.heatmap ?? {};

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          childAspectRatio: 1.0,
        ),
        itemCount: 42,
        itemBuilder: (context, index) {
          final dayNum = index - firstWeekday + 1;
          if (dayNum < 1 || dayNum > daysInMonth) {
            return const SizedBox.shrink();
          }

          final date = DateTime(month.year, month.month, dayNum);
          final isToday = DateUtils.isSameDay(date, today);
          final isFuture = date.isAfter(today);
          final dateStr = _dateKey(date);
          final rawPrayerCount = heatmap[dateStr];

          // Hari lampau tanpa data di heatmap → anggap 0 (kosong/merah)
          final isPastDate = !isFuture && !isToday;
          final prayerCount = rawPrayerCount ?? (isPastDate ? 0 : null);

          return GestureDetector(
            onTap: isFuture
                ? null
                : () => _loadAndShowDayDetail(context, date),
            child: _buildDayCell(dayNum, isToday, isFuture, prayerCount),
          );
        },
      ),
    );
  }

  Widget _buildDayCell(int day, bool isToday, bool isFuture, int? prayerCount) {
    Color bgColor;
    Color textColor;
    List<BoxShadow>? shadow;
    Color dotColor = AppTheme.white;
    Color dotBgColor = AppTheme.white.withOpacity(0.3);

    if (isFuture) {
      bgColor = Colors.transparent;
      textColor = AppTheme.grey200;
      dotColor = Colors.transparent;
      dotBgColor = Colors.transparent;
    } else if (prayerCount == null) {
      bgColor = AppTheme.bgColor;
      textColor = AppTheme.textPrimary;
      dotColor = Colors.transparent;
      dotBgColor = Colors.transparent;
    } else if (prayerCount == 0) {
      bgColor = const Color(0xFFEF4444).withOpacity(0.12);
      textColor = const Color(0xFFDC2626);
      dotColor = const Color(0xFFDC2626);
      dotBgColor = const Color(0xFFEF4444).withOpacity(0.3);
    } else {
      // GitHub Heatmap style colors
      switch (prayerCount) {
        case 1:
          bgColor = const Color(0xFF9BE9A8); // Sangat muda
          textColor = AppTheme.darkGreen;
          dotColor = AppTheme.darkGreen;
          dotBgColor = AppTheme.darkGreen.withOpacity(0.2);
          break;
        case 2:
          bgColor = const Color(0xFF40C463); // Muda
          textColor = AppTheme.darkGreen;
          dotColor = AppTheme.darkGreen;
          dotBgColor = AppTheme.darkGreen.withOpacity(0.2);
          break;
        case 3:
          bgColor = const Color(0xFF30A14E); // Medium
          textColor = AppTheme.white;
          dotColor = AppTheme.white;
          dotBgColor = AppTheme.white.withOpacity(0.3);
          break;
        case 4:
          bgColor = const Color(0xFF216E39); // Tua
          textColor = AppTheme.white;
          dotColor = AppTheme.white;
          dotBgColor = AppTheme.white.withOpacity(0.3);
          break;
        case 5:
        default:
          bgColor = AppTheme.deepGreen; // Pekat
          textColor = AppTheme.white;
          dotColor = AppTheme.white;
          dotBgColor = AppTheme.white.withOpacity(0.3);
          break;
      }
    }

    if (isToday) {
      shadow = [
        BoxShadow(
          color: AppTheme.primaryGreen.withOpacity(0.3),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      // If it isToday we can use a border to denote "Today" instead of changing the heatmap color,
      // Or we can apply the boundary styling alongside the heatmap color.
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: shadow,
        border: isToday ? Border.all(color: AppTheme.gold, width: 2) : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$day',
            style: TextStyle(
              fontSize: 13,
              fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
              color: textColor,
            ),
          ),
          if (!isFuture && prayerCount != null) ...[
            const SizedBox(height: 2),
            _buildMiniDots(prayerCount, dotColor, dotBgColor),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniDots(int count, Color dotColor, Color dotBgColor) {
    if (count == 0) {
      return const Icon(Icons.close_rounded, size: 8, color: Color(0xFFDC2626));
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        return Container(
          width: 3,
          height: 3,
          margin: const EdgeInsets.symmetric(horizontal: 0.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i < count ? dotColor : dotBgColor,
          ),
        );
      }),
    );
  }

  // ═══════════════════════════════════════════════════
  // ───── Legend ─────────────────────────────────────
  // ═══════════════════════════════════════════════════

  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _legendChip(
              const Color(0xFFEF4444).withOpacity(0.12),
              const Color(0xFFDC2626),
              'Kosong',
            ),
            _legendChip(const Color(0xFF9BE9A8), AppTheme.darkGreen, '1'),
            _legendChip(const Color(0xFF40C463), AppTheme.darkGreen, '2'),
            _legendChip(const Color(0xFF30A14E), AppTheme.white, '3'),
            _legendChip(const Color(0xFF216E39), AppTheme.white, '4'),
            _legendChip(AppTheme.deepGreen, AppTheme.white, '5'),
          ],
        ),
      ),
    );
  }

  Widget _legendChip(Color bg, Color dotColor, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: dotColor.withOpacity(0.3), width: 1),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: dotColor,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════
  // ═══════════════════════════════════════════════════
  // ───── Day Detail Bottom Sheet (data dari API) ────
  // ═══════════════════════════════════════════════════

  void _showDayDetailSheet(
      BuildContext context, DateTime date, WaliDayDetailData detail) {
    final dayName = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(date);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: AppTheme.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
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
                          color: AppTheme.primaryGreen.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.mosque_rounded,
                          color: AppTheme.primaryGreen,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Detail Laporan',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              dayName,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryGreen,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: AppTheme.grey100,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 20,
                            color: AppTheme.grey600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Scrollable content
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    children: [
                      // ── Read-only notice ──
                      Container(
                        margin: const EdgeInsets.only(bottom: 24),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.bgColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.primaryGreen.withOpacity(0.2),
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
                                'Hanya wali yang dapat melihat data histori ini',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ── Belum ada data ──
                      if (!detail.hasData && !date.isBefore(DateTime(
                        DateTime.now().year,
                        DateTime.now().month,
                        DateTime.now().day,
                      )))
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppTheme.grey100.withOpacity(0.5),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMd),
                          ),
                          child: const Column(
                            children: [
                              Icon(Icons.info_outline_rounded,
                                  color: AppTheme.grey400, size: 32),
                              SizedBox(height: 8),
                              Text(
                                'Belum ada data ibadah di hari ini',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // ── Shalat List ──
                      if (detail.hasData || date.isBefore(DateTime(
                        DateTime.now().year,
                        DateTime.now().month,
                        DateTime.now().day,
                      )))
                        ...detail.prayers
                            .map((item) => _buildReportItem(item)),

                      // ── Seksi: Berbuat Baik ──
                      if (detail.extras != null &&
                          detail.extras!.deeds.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _buildSectionHeader(
                          icon: Icons.volunteer_activism_rounded,
                          iconColor: AppTheme.primaryGreen,
                          title: 'Perbuatan Baik',
                          subtitle:
                              '${detail.extras!.deeds.length} kebaikan tercatat',
                        ),
                        const SizedBox(height: 12),
                        ...detail.extras!.deeds.map(
                          (deed) => _buildDeedItem(
                            icon: _getDeedIcon(deed),
                            label: deed,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                      ],

                      // ── Seksi: Bangun Pagi ──
                      if (detail.extras != null &&
                          detail.extras!.wakeUpTime != null) ...[
                        const SizedBox(height: 20),
                        _buildSectionHeader(
                          icon: Icons.alarm_rounded,
                          iconColor: AppTheme.gold,
                          title: 'Bangun Tepat Waktu',
                          subtitle: 'Sebelum adzan Subuh',
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.white,
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMd),
                            border: Border.all(
                                color: AppTheme.grey100, width: 1),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppTheme.gold.withOpacity(0.12),
                                ),
                                child: const Icon(
                                  Icons.wb_twilight_rounded,
                                  color: AppTheme.gold,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Bangun Subuh',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      '${detail.extras!.wakeUpTime} WIB',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.grey400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.gold.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '+${detail.extras!.wakeUpPoints} poin',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.gold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 60),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Helper Builders ──

  Widget _buildSectionHeader({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: AppTheme.grey400),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDeedItem({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.grey100, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.12),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const Spacer(),
          Icon(Icons.check_circle_rounded, color: color, size: 20),
        ],
      ),
    );
  }

  IconData _getDeedIcon(String deed) {
    final lower = deed.toLowerCase();
    if (lower.contains('tahajjud')) return Icons.nightlight_rounded;
    if (lower.contains('tadarus') || lower.contains('quran')) {
      return Icons.menu_book_rounded;
    }
    if (lower.contains('dzikir')) return Icons.self_improvement_rounded;
    if (lower.contains('dhuha')) return Icons.wb_sunny_rounded;
    if (lower.contains('puasa')) return Icons.favorite_rounded;
    if (lower.contains('shadaqah') || lower.contains('sedekah')) {
      return Icons.volunteer_activism_rounded;
    }
    if (lower.contains('silaturahmi')) return Icons.people_alt_rounded;
    return Icons.star_rounded;
  }

  Widget _buildReportItem(WaliPrayerItem item) {
    Color iconBgColor;
    Color iconColor;
    IconData icon;
    String statusText;
    Color statusColor;

    if (item.isJamaah) {
      iconBgColor = AppTheme.primaryGreen.withOpacity(0.12);
      iconColor = AppTheme.primaryGreen;
      icon = Icons.check_circle_rounded;
      statusText = 'Berjamaah';
      statusColor = AppTheme.primaryGreen;
    } else if (item.isDone) {
      iconBgColor = AppTheme.primaryGreen.withOpacity(0.10);
      iconColor = AppTheme.primaryGreen;
      icon = Icons.check_circle_outline_rounded;
      statusText = 'Munfarid (Sendiri)';
      statusColor = AppTheme.primaryGreen;
    } else if (item.isMissed) {
      iconBgColor = const Color(0xFFEF4444).withOpacity(0.12);
      iconColor = const Color(0xFFEF4444);
      icon = Icons.cancel_outlined;
      statusText = 'Tidak Mengerjakan';
      statusColor = const Color(0xFFEF4444);
    } else {
      iconBgColor = AppTheme.primaryGreen.withOpacity(0.06);
      iconColor = AppTheme.primaryGreen.withOpacity(0.5);
      icon = Icons.schedule_rounded;
      statusText = 'Belum Waktunya';
      statusColor = AppTheme.primaryGreen;
    }

    const defaultTimes = {
      'Subuh': '04:30',
      'Dzuhur': '11:45',
      'Ashar': '15:05',
      'Maghrib': '17:50',
      'Isya': '19:05',
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.grey100, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconBgColor,
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  defaultTimes[item.name] ?? '',
                  style: const TextStyle(
                      fontSize: 13, color: AppTheme.grey400),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
