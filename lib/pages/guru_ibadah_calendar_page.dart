import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../theme.dart';
import '../services/guru_ibadah_service.dart';

/// Halaman kalender ibadah siswa untuk guru.
/// Guru bisa lihat rekap bulanan & edit ibadah harian siswa.
class GuruIbadahCalendarPage extends StatefulWidget {
  final int studentId;
  final String studentName;
  final String className;

  const GuruIbadahCalendarPage({
    super.key,
    required this.studentId,
    required this.studentName,
    this.className = '',
  });

  @override
  State<GuruIbadahCalendarPage> createState() =>
      _GuruIbadahCalendarPageState();
}

class _GuruIbadahCalendarPageState extends State<GuruIbadahCalendarPage>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late DateTime _currentMonth;
  late AnimationController _fadeController;

  static const int _totalPages = 120;
  static const int _centrePage = 60;

  final Map<String, int> _prayerData = {};
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

    _loadMonthData(_currentMonth);
  }

  Future<void> _loadMonthData(DateTime month) async {
    final monthKey = DateFormat('yyyy-MM').format(month);
    if (_loadedMonths.contains(monthKey)) return;

    setState(() => _isLoadingData = true);

    try {
      final data = await GuruIbadahService.getMonthData(
        studentId: widget.studentId,
        month: monthKey,
      );
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

  /// Refresh data bulan tertentu (setelah edit)
  Future<void> _refreshMonthData(DateTime month) async {
    final monthKey = DateFormat('yyyy-MM').format(month);
    _loadedMonths.remove(monthKey);

    // Hapus data bulan ini dari cache
    final prefix = monthKey;
    _prayerData.removeWhere((key, _) => key.startsWith(prefix));

    await _loadMonthData(month);
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
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildPageHeader(),
            Expanded(
              child: FadeTransition(
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
                        _buildCalendarHeader(),
                        _buildDayLabels(),
                        Expanded(
                          child: PageView.builder(
                            controller: _pageController,
                            scrollDirection: Axis.vertical,
                            itemCount: _totalPages,
                            onPageChanged: (page) {
                              setState(() {});
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
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPageHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: AppTheme.mainGradient,
              ),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  color: AppTheme.primaryGreen,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.mosque_rounded,
                      size: 14,
                      color: AppTheme.softPurple,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Rekap Ibadah',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  widget.studentName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (widget.className.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.className,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.grey400,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarHeader() {
    return AnimatedBuilder(
      animation: _pageController,
      builder: (context, _) {
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
              if (_isLoadingData)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primaryGreen,
                  ),
                )
              else
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
                  color:
                      d == 'JUM' ? AppTheme.primaryGreen : AppTheme.grey400,
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
        itemCount: 42,
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
            onTap: () {
              if (isFuture) {
                _showFutureDateSheet(context, date);
              } else {
                _showDayDetailSheet(context, date, prayerCount ?? 0);
              }
            },
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

    if (isFuture) {
      bgColor = Colors.transparent;
      textColor = AppTheme.grey200;
    } else if (prayerCount == null) {
      bgColor = Colors.transparent;
      textColor = AppTheme.textPrimary;
    } else if (prayerCount == 0) {
      bgColor = const Color(0xFFEF4444).withOpacity(0.15);
      textColor = const Color(0xFFDC2626);
    } else {
      final intensity = (prayerCount / 5.0).clamp(0.0, 1.0);
      bgColor = AppTheme.primaryGreen.withOpacity(0.08 + intensity * 0.30);
      textColor =
          prayerCount >= 3 ? AppTheme.deepGreen : AppTheme.primaryGreen;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: isToday ? null : bgColor,
        gradient: isToday ? AppTheme.mainGradient : null,
        borderRadius: BorderRadius.circular(10),
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
      return const Icon(Icons.close_rounded,
          size: 8, color: Color(0xFFEF4444));
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
            color: i < count ? AppTheme.primaryGreen : AppTheme.grey200,
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
          _legendItem(AppTheme.primaryGreen.withOpacity(0.12),
              AppTheme.grey600, '1-2'),
          const SizedBox(width: 12),
          _legendItem(AppTheme.primaryGreen.withOpacity(0.25),
              AppTheme.grey600, '3-4'),
          const SizedBox(width: 12),
          _legendItem(AppTheme.primaryGreen.withOpacity(0.38),
              AppTheme.deepGreen, '5/5'),
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

  void _showFutureDateSheet(BuildContext context, DateTime date) {
    HapticFeedback.heavyImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.grey100,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.grey200, width: 1.5),
              ),
              child: const Center(
                child: Text('📅', style: TextStyle(fontSize: 32)),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Tanggal belum tiba',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Data ibadah hanya bisa dilihat\nuntuk tanggal yang sudah lewat.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.grey600,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppTheme.mainGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Oke, paham 👍',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _showDayDetailSheet(
      BuildContext context, DateTime date, int prayerCount) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GuruIbadahDaySheet(
        studentId: widget.studentId,
        studentName: widget.studentName,
        date: date,
        initialPrayerCount: prayerCount,
        onSaved: () {
          // Refresh data bulan setelah edit
          _refreshMonthData(DateTime(date.year, date.month));
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Bottom Sheet: Detail ibadah harian + edit
// ═══════════════════════════════════════════════════════════

enum _PrayerStatus { done, doneJamaah, missed, upcoming }

class _PrayerInfo {
  final String name;
  final String arabicName;
  final String time;
  final IconData icon;

  const _PrayerInfo({
    required this.name,
    required this.arabicName,
    required this.time,
    required this.icon,
  });
}

const List<_PrayerInfo> _defaultPrayers = [
  _PrayerInfo(
      name: 'Subuh',
      arabicName: 'الفجر',
      time: '04:38',
      icon: Icons.wb_twilight_rounded),
  _PrayerInfo(
      name: 'Dzuhur',
      arabicName: 'الظهر',
      time: '12:15',
      icon: Icons.wb_sunny_rounded),
  _PrayerInfo(
      name: 'Ashar',
      arabicName: 'العصر',
      time: '15:30',
      icon: Icons.wb_sunny_outlined),
  _PrayerInfo(
      name: 'Maghrib',
      arabicName: 'المغرب',
      time: '18:05',
      icon: Icons.wb_twilight_rounded),
  _PrayerInfo(
      name: 'Isya',
      arabicName: 'العشاء',
      time: '19:18',
      icon: Icons.nights_stay_rounded),
];

class _GuruIbadahDaySheet extends StatefulWidget {
  final int studentId;
  final String studentName;
  final DateTime date;
  final int initialPrayerCount;
  final VoidCallback? onSaved;

  const _GuruIbadahDaySheet({
    required this.studentId,
    required this.studentName,
    required this.date,
    required this.initialPrayerCount,
    this.onSaved,
  });

  @override
  State<_GuruIbadahDaySheet> createState() => _GuruIbadahDaySheetState();
}

class _GuruIbadahDaySheetState extends State<_GuruIbadahDaySheet> {
  Map<String, _PrayerStatus> _statuses = {};
  Map<String, _PrayerStatus> _originalStatuses = {};
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;
  String? _wakeUpTime;
  List<String> _deeds = [];

  @override
  void initState() {
    super.initState();
    // Default statuses
    for (final p in _defaultPrayers) {
      _statuses[p.name] = _PrayerStatus.upcoming;
    }
    _loadDayData();
  }

  Future<void> _loadDayData() async {
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(widget.date);
      final data = await GuruIbadahService.getDayData(
        studentId: widget.studentId,
        date: dateStr,
      );
      if (!mounted) return;
      setState(() {
        for (final entry in data.prayers.entries) {
          switch (entry.value.status) {
            case 'done':
              _statuses[entry.key] = _PrayerStatus.done;
              break;
            case 'done_jamaah':
              _statuses[entry.key] = _PrayerStatus.doneJamaah;
              break;
            default:
              _statuses[entry.key] = _PrayerStatus.missed;
          }
        }
        // Tandai yang tidak ada data sebagai missed (bukan upcoming)
        for (final p in _defaultPrayers) {
          if (!data.prayers.containsKey(p.name)) {
            _statuses[p.name] = _PrayerStatus.upcoming;
          }
        }
        _originalStatuses = Map.from(_statuses);
        _wakeUpTime = data.wakeUpTime;
        _deeds = data.deeds;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      debugPrint('Gagal load day data: $e');
    }
  }

  Future<void> _saveToServer() async {
    HapticFeedback.lightImpact();
    setState(() => _isSaving = true);

    final dateStr = DateFormat('yyyy-MM-dd').format(widget.date);
    final prayers = <String, String>{};
    _statuses.forEach((name, status) {
      String statusStr;
      switch (status) {
        case _PrayerStatus.done:
          statusStr = 'done';
          break;
        case _PrayerStatus.doneJamaah:
          statusStr = 'done_jamaah';
          break;
        default:
          statusStr = 'missed';
      }
      prayers[name] = statusStr;
    });

    try {
      await GuruIbadahService.updatePrayers(
        studentId: widget.studentId,
        date: dateStr,
        prayers: prayers,
      );

      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _isEditing = false;
        _originalStatuses = Map.from(_statuses);
      });

      widget.onSaved?.call();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Data ibadah berhasil diperbarui'),
          backgroundColor: AppTheme.primaryGreen,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Gagal menyimpan data ibadah'),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _cycleStatus(String prayerName) {
    if (!_isEditing) return;
    HapticFeedback.selectionClick();

    setState(() {
      final current = _statuses[prayerName] ?? _PrayerStatus.upcoming;
      switch (current) {
        case _PrayerStatus.upcoming:
        case _PrayerStatus.missed:
          _statuses[prayerName] = _PrayerStatus.done;
          break;
        case _PrayerStatus.done:
          _statuses[prayerName] = _PrayerStatus.doneJamaah;
          break;
        case _PrayerStatus.doneJamaah:
          _statuses[prayerName] = _PrayerStatus.missed;
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(widget.date);
    final doneCount = _statuses.values
        .where(
            (s) => s == _PrayerStatus.done || s == _PrayerStatus.doneJamaah)
        .length;

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20),
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

          // Header: Date + Edit button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.studentName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateStr,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.grey600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Edit / Cancel button
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    if (_isEditing) {
                      // Cancel — restore original statuses
                      setState(() {
                        _statuses = Map.from(_originalStatuses);
                        _isEditing = false;
                      });
                    } else {
                      setState(() => _isEditing = true);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _isEditing
                          ? Colors.red.shade50
                          : AppTheme.primaryGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isEditing ? Icons.close_rounded : Icons.edit_rounded,
                          size: 16,
                          color: _isEditing
                              ? Colors.red.shade400
                              : AppTheme.primaryGreen,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isEditing ? 'Batal' : 'Edit',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _isEditing
                                ? Colors.red.shade400
                                : AppTheme.primaryGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Score bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: doneCount >= 5
                    ? AppTheme.primaryGreen.withOpacity(0.08)
                    : doneCount > 0
                        ? AppTheme.primaryGreen.withOpacity(0.05)
                        : AppTheme.grey100.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    doneCount >= 5
                        ? Icons.emoji_events_rounded
                        : Icons.mosque_rounded,
                    color: doneCount >= 5
                        ? AppTheme.gold
                        : AppTheme.primaryGreen,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '$doneCount/5 Shalat',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: doneCount >= 5
                          ? AppTheme.deepGreen
                          : AppTheme.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  // Mini dots
                  Row(
                    children: List.generate(5, (i) {
                      return Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i < doneCount
                              ? AppTheme.primaryGreen
                              : AppTheme.grey200,
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          if (_isEditing) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.softBlue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppTheme.softBlue.withOpacity(0.2), width: 1),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 16, color: AppTheme.softBlue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tap shalat untuk ubah status: Sendiri → Jamaah → Tidak',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.softBlue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Prayer list
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(color: AppTheme.primaryGreen),
            )
          else
            ...List.generate(_defaultPrayers.length, (i) {
              final prayer = _defaultPrayers[i];
              final status =
                  _statuses[prayer.name] ?? _PrayerStatus.upcoming;
              return _buildPrayerRow(prayer, status);
            }),

          // Extras section (read-only)
          if (!_isLoading && (_wakeUpTime != null || _deeds.isNotEmpty)) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.bgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_wakeUpTime != null) ...[
                      Row(
                        children: [
                          const Icon(Icons.alarm_rounded,
                              size: 16, color: AppTheme.gold),
                          const SizedBox(width: 8),
                          Text(
                            'Bangun: $_wakeUpTime',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (_deeds.isNotEmpty) ...[
                      if (_wakeUpTime != null)
                        const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.star_rounded,
                              size: 16, color: AppTheme.gold),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Kebaikan: ${_deeds.join(', ')}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],

          // Save button (only in edit mode)
          if (_isEditing) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppTheme.mainGradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: AppTheme.greenGlow,
                  ),
                  child: TextButton(
                    onPressed: _isSaving ? null : _saveToServer,
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.white,
                            ),
                          )
                        : const Text(
                            'Simpan Perubahan',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildPrayerRow(_PrayerInfo prayer, _PrayerStatus status) {
    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    switch (status) {
      case _PrayerStatus.done:
        statusColor = AppTheme.primaryGreen;
        statusLabel = 'Sendiri';
        statusIcon = Icons.check_circle_rounded;
        break;
      case _PrayerStatus.doneJamaah:
        statusColor = AppTheme.deepGreen;
        statusLabel = 'Jamaah';
        statusIcon = Icons.groups_rounded;
        break;
      case _PrayerStatus.missed:
        statusColor = const Color(0xFFEF4444);
        statusLabel = 'Tidak';
        statusIcon = Icons.cancel_rounded;
        break;
      case _PrayerStatus.upcoming:
        statusColor = AppTheme.grey400;
        statusLabel = 'Belum';
        statusIcon = Icons.remove_circle_outline_rounded;
        break;
    }

    return GestureDetector(
      onTap: () => _cycleStatus(prayer.name),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _isEditing
              ? statusColor.withOpacity(0.04)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: _isEditing
              ? Border.all(color: statusColor.withOpacity(0.15), width: 1)
              : null,
        ),
        child: Row(
          children: [
            // Prayer icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(prayer.icon, color: statusColor, size: 18),
            ),
            const SizedBox(width: 12),

            // Prayer name & time
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        prayer.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        prayer.arabicName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.grey400,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    prayer.time,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.grey400,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // Status badge
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(statusIcon, size: 14, color: statusColor),
                  const SizedBox(width: 4),
                  Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ),

            if (_isEditing) ...[
              const SizedBox(width: 6),
              Icon(Icons.swap_vert_rounded,
                  size: 16, color: AppTheme.grey400),
            ],
          ],
        ),
      ),
    );
  }
}
