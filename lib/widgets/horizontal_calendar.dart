import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme.dart';
import '../services/prayer_service.dart';

abstract class CalendarDateCountUpdater {
  void updateDateCount(String dateKey, int count);
}

class HorizontalCalendar extends StatefulWidget {
  final ValueChanged<DateTime>? onDateTap;

  const HorizontalCalendar({super.key, this.onDateTap});

  @override
  State<HorizontalCalendar> createState() => _HorizontalCalendarState();
}

class _HorizontalCalendarState extends State<HorizontalCalendar>
  with SingleTickerProviderStateMixin
  implements CalendarDateCountUpdater {
  DateTime selectedDate = DateTime.now();
  late ScrollController _scrollController;
  late AnimationController _nudgeController;
  late Animation<double> _nudgeAnimation;

  // Number of days to show before and after today
  static const int _daysRange = 14;
  // Index of today in the list
  static const int _todayIndex = _daysRange;
  // Item width: 68 card + 4+4 margin = 76
  static const double _itemWidth = 76.0;
  // Horizontal padding of the list
  static const double _listPadding = 20.0;

  // Data jumlah shalat per tanggal dari database
  // Key: 'YYYY-MM-DD', Value: jumlah shalat done (0-5)
  Map<String, int> _prayerData = {};
  bool _isLoadingPrayers = true;

  double _calcLeftAlignedOffset() {
    // Align today's card left edge with the greeting header (padding 24px)
    const double greetingLeftPadding = 24.0;
    const double cardMarginLeft = 4.0;
    return _listPadding +
        _todayIndex * _itemWidth +
        cardMarginLeft -
        greetingLeftPadding;
  }

  @override
  void initState() {
    super.initState();

    // Nudge animation: slide left ~30px then back (like old Android notif bar)
    _nudgeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _nudgeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 30.0)
          .chain(CurveTween(curve: Curves.easeOutCubic)), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 30.0, end: 0.0)
          .chain(CurveTween(curve: Curves.easeInOutCubic)), weight: 60),
    ]).animate(_nudgeController);

    // Use initialScrollOffset so today is positioned correctly on first frame
    _scrollController = ScrollController(
      initialScrollOffset: _calcLeftAlignedOffset(),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Clamp to valid scroll range after layout is complete
      final target = _calcLeftAlignedOffset()
          .clamp(0.0, _scrollController.position.maxScrollExtent);
      if ((_scrollController.offset - target).abs() > 1) {
        _scrollController.jumpTo(target);
      }

      // Start nudge animation after a short delay
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _nudgeController.forward();
      });
    });

    // Load data shalat dari database
    _loadPrayerData();
  }

  /// Muat data shalat dari server untuk bulan ini dan bulan sebelumnya
  Future<void> _loadPrayerData() async {
    try {
      final now = DateTime.now();
      final thisMonth = DateFormat('yyyy-MM').format(now);
      final prevMonth = DateFormat('yyyy-MM').format(
        DateTime(now.year, now.month - 1),
      );

      // Ambil data 2 bulan (bulan ini + bulan lalu) agar kalender horizontal terisi
      final results = await Future.wait([
        PrayerService.getPrayersByMonth(thisMonth),
        PrayerService.getPrayersByMonth(prevMonth),
      ]);

      if (!mounted) return;
      setState(() {
        for (final result in results) {
          _prayerData.addAll(result.dailyCounts);
        }
        _isLoadingPrayers = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingPrayers = false);
      debugPrint('Gagal load prayer data: $e');
    }
  }

  /// Public method untuk refresh data (dipanggil dari parent)
  Future<void> refreshData() async {
    setState(() {
      _prayerData = {};
      _isLoadingPrayers = true;
    });
    await _loadPrayerData();
  }

  /// Update dots untuk tanggal tertentu secara langsung (tanpa fetch ulang)
  @override
  void updateDateCount(String dateKey, int count) {
    if (!mounted) return;
    setState(() {
      _prayerData[dateKey] = count;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _nudgeController.dispose();
    super.dispose();
  }

  List<DateTime> _generateDates() {
    List<DateTime> dates = [];
    DateTime now = DateTime.now();
    for (int i = -_daysRange; i <= _daysRange; i++) {
      dates.add(now.add(Duration(days: i)));
    }
    return dates;
  }

  @override
  Widget build(BuildContext context) {
    final dates = _generateDates();

    return AnimatedBuilder(
      animation: _nudgeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(-_nudgeAnimation.value, 0),
          child: child,
        );
      },
      child: SizedBox(
        height: 108,
        child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: dates.length,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemBuilder: (context, index) {
          final date = dates[index];
          final dayOffset = index - _todayIndex;
          final isSelected = DateUtils.isSameDay(date, selectedDate);
          final isToday = DateUtils.isSameDay(date, DateTime.now());
          final dateKey = DateFormat('yyyy-MM-dd').format(date);
          // Hanya hitung shalat (5 waktu), bukan kebaikan lain
          final prayerCount = (_prayerData[dateKey] ?? 0).clamp(0, 5);

          return GestureDetector(
            onTap: () {
              // Tidak mengubah selectedDate — efek hijau tetap di hari ini
              widget.onDateTap?.call(date);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              width: 68,
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                gradient: isSelected ? AppTheme.mainGradient : null,
                color: isSelected ? null : AppTheme.white,
                borderRadius: BorderRadius.circular(22),
                border: isToday && !isSelected
                    ? Border.all(color: AppTheme.emerald, width: 2)
                    : isSelected
                        ? null
                        : Border.all(color: AppTheme.grey100, width: 1),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _getShortDay(date),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? AppTheme.white.withOpacity(0.8)
                          : AppTheme.grey400,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    width: isSelected ? 38 : 34,
                    height: isSelected ? 38 : 34,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.white.withOpacity(0.2)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      DateFormat('d').format(date),
                      style: TextStyle(
                        fontSize: isSelected ? 20 : 18,
                        fontWeight: FontWeight.w800,
                        color: isSelected
                            ? AppTheme.white
                            : AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (!date.isAfter(DateTime.now()))
                    _buildPrayerDots(prayerCount, isSelected)
                  else
                    const SizedBox(height: 5),
                ],
              ),
            ),
          );
        },
      ),
    ),
    );
  }

  Widget _buildPrayerDots(int count, bool isOnGreen) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final filled = i < count;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 5,
          height: 5,
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled
                ? (isOnGreen ? AppTheme.white : AppTheme.emerald)
                : (isOnGreen
                    ? AppTheme.white.withOpacity(0.25)
                    : AppTheme.grey200),
          ),
        );
      }),
    );
  }

  String _getShortDay(DateTime date) {
    const days = ['MIN', 'SEN', 'SEL', 'RAB', 'KAM', 'JUM', 'SAB'];
    return days[date.weekday % 7];
  }
}
