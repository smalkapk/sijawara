import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../theme.dart';
import '../services/prayer_service.dart';
import 'prayer_countdown.dart';

/// Monthly calendar with prayer completion heatmap.
/// Green intensity = prayers done (1-5), red = nothing logged.
class MonthlyCalendar extends StatefulWidget {
  const MonthlyCalendar({super.key});

  @override
  State<MonthlyCalendar> createState() => _MonthlyCalendarState();
}

class _MonthlyCalendarState extends State<MonthlyCalendar>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late DateTime _currentMonth;
  late AnimationController _fadeController;

  // Centre page index so user can swipe both directions
  static const int _totalPages = 120; // 10 years range
  static const int _centrePage = 60; // current month index

  // Data shalat dari database: date (YYYY-MM-DD) -> jumlah shalat done (0-5)
  final Map<String, int> _prayerData = {};
  // Bulan yang sudah di-load datanya
  final Set<String> _loadedMonths = {};
  bool _isLoadingData = false;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
    _pageController = PageController(initialPage: _centrePage);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();

    // Load data bulan ini dari database
    _loadMonthData(_currentMonth);
  }

  /// Muat data shalat sebulan dari server
  Future<void> _loadMonthData(DateTime month) async {
    final monthKey = DateFormat('yyyy-MM').format(month);
    if (_loadedMonths.contains(monthKey)) return; // sudah di-load

    setState(() => _isLoadingData = true);

    try {
      final data = await PrayerService.getPrayersByMonth(monthKey);
      if (!mounted) return;
      setState(() {
        _prayerData.addAll(data.dailyCounts);
        _loadedMonths.add(monthKey);
        _isLoadingData = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingData = false);
      debugPrint('Gagal load data bulan $monthKey: $e');
    }
  }

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  DateTime _monthFromPage(int page) {
    final diff = page - _centrePage;
    return DateTime(_currentMonth.year, _currentMonth.month + diff);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _fadeController,
        curve: Curves.easeOutCubic,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppTheme.grey100, width: 1),
          ),
          child: Column(
            children: [
              _buildHeader(),
              _buildDayLabels(),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  scrollDirection: Axis.vertical,
                  itemCount: _totalPages,
                  onPageChanged: (page) {
                    setState(() {});
                    // Auto-load data saat swipe ke bulan baru
                    final month = _monthFromPage(page);
                    _loadMonthData(month);
                  },
                  itemBuilder: (context, page) {
                    final month = _monthFromPage(page);
                    return _buildMonthGrid(month);
                  },
                ),
              ),
              _buildLegend(),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return AnimatedBuilder(
      animation: _pageController,
      builder: (context, _) {
        // Get current displayed page
        final page = _pageController.hasClients
            ? (_pageController.page?.round() ?? _centrePage)
            : _centrePage;
        final month = _monthFromPage(page);
        final monthName = DateFormat('MMMM yyyy', 'id_ID').format(month);

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppTheme.mainGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: AppTheme.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'REKAP BULANAN',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.grey400,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      monthName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
              // Swipe hint
              Column(
                children: [
                  Icon(Icons.keyboard_arrow_up_rounded,
                      size: 16, color: AppTheme.grey400),
                  Text(
                    'Swipe',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.grey400,
                    ),
                  ),
                  Icon(Icons.keyboard_arrow_down_rounded,
                      size: 16, color: AppTheme.grey400),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDayLabels() {
    const days = ['MIN', 'SEN', 'SEL', 'RAB', 'KAM', 'JUM', 'SAB'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: days.map((d) {
          return Expanded(
            child: Center(
              child: Text(
                d,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: d == 'JUM'
                      ? AppTheme.primaryGreen
                      : AppTheme.grey400,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMonthGrid(DateTime month) {
    final today = DateTime.now();
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final firstWeekday = DateTime(month.year, month.month, 1).weekday % 7;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          childAspectRatio: 1.0,
        ),
        itemCount: 42, // 6 rows × 7 columns
        itemBuilder: (context, index) {
          final dayNum = index - firstWeekday + 1;

          if (dayNum < 1 || dayNum > daysInMonth) {
            return const SizedBox.shrink();
          }

          final date = DateTime(month.year, month.month, dayNum);
          final isToday = DateUtils.isSameDay(date, today);
          final isFuture = date.isAfter(today);
          final key = _dateKey(date);
          final prayerCount = _prayerData[key];

          return GestureDetector(
            onTap: () => _showDayDetail(context, date, isFuture, prayerCount ?? 0),
            child: _buildDayCell(dayNum, isToday, isFuture, prayerCount),
          );
        },
      ),
    );
  }

  Widget _buildDayCell(
      int day, bool isToday, bool isFuture, int? prayerCount) {
    Color bgColor;
    Color textColor;
    Border? border;

    if (isFuture) {
      bgColor = Colors.transparent;
      textColor = AppTheme.grey200;
      border = null;
    } else if (prayerCount == null) {
      // No data yet (today, not yet tracked)
      bgColor = Colors.transparent;
      textColor = AppTheme.textPrimary;
      border = null;
    } else if (prayerCount == 0) {
      // No prayers — red
      bgColor = const Color(0xFFEF4444).withOpacity(0.15);
      textColor = const Color(0xFFDC2626);
      border = null;
    } else {
      // 1-5 prayers — green with intensity
      final intensity = (prayerCount / 5.0).clamp(0.0, 1.0);
      bgColor = AppTheme.primaryGreen.withOpacity(0.08 + intensity * 0.30);
      textColor = prayerCount >= 3 ? AppTheme.deepGreen : AppTheme.primaryGreen;
      border = null;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: isToday ? null : bgColor,
        gradient: isToday ? AppTheme.mainGradient : null,
        borderRadius: BorderRadius.circular(10),
        border: border,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$day',
            style: TextStyle(
              fontSize: 13,
              fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
              color: isToday ? AppTheme.white : textColor,
            ),
          ),
          if (!isFuture && prayerCount != null && !isToday) ...[
            const SizedBox(height: 2),
            _buildMiniDots(prayerCount),
          ],
          if (isToday) ...[
            const SizedBox(height: 1),
            Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: AppTheme.white,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniDots(int count) {
    if (count == 0) {
      return Icon(Icons.close_rounded, size: 8, color: const Color(0xFFEF4444));
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
            color: i < count
                ? AppTheme.primaryGreen
                : AppTheme.grey200,
          ),
        );
      }),
    );
  }

  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _legendItem(const Color(0xFFEF4444).withOpacity(0.15),
              const Color(0xFFDC2626), 'Kosong'),
          const SizedBox(width: 12),
          _legendItem(
              AppTheme.primaryGreen.withOpacity(0.12), AppTheme.grey600, '1-2'),
          const SizedBox(width: 12),
          _legendItem(
              AppTheme.primaryGreen.withOpacity(0.25), AppTheme.grey600, '3-4'),
          const SizedBox(width: 12),
          _legendItem(
              AppTheme.primaryGreen.withOpacity(0.38), AppTheme.deepGreen, '5/5'),
        ],
      ),
    );
  }

  Widget _legendItem(Color bg, Color textColor, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ],
    );
  }

  void _showDayDetail(BuildContext context, DateTime date, bool isFuture, int count) {
    if (isFuture) {
      showFutureDateBlockedSheet(context, date);
    } else {
      showPrayerTrackingSheet(
        context,
        date: date,
        prayerCount: count,
      );
    }
  }
}
