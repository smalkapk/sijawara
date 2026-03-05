import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../theme.dart';
import '../services/prayer_service.dart';
import '../services/location_service.dart';

// ───── Data Models ─────
class PrayerTime {
  final String name;
  final String arabicName;
  final String time;
  final IconData icon;
  final int hour;
  final int minute;

  const PrayerTime({
    required this.name,
    required this.arabicName,
    required this.time,
    required this.icon,
    required this.hour,
    required this.minute,
  });
}

enum PrayerStatus { upcoming, done, doneJamaah, missed }

// ───── Public Prayers List ─────
const List<PrayerTime> defaultPrayers = [
  PrayerTime(name: 'Subuh', arabicName: 'الفجر', time: '04:38', icon: Icons.wb_twilight_rounded, hour: 4, minute: 38),
  PrayerTime(name: 'Dzuhur', arabicName: 'الظهر', time: '12:15', icon: Icons.wb_sunny_rounded, hour: 12, minute: 15),
  PrayerTime(name: 'Ashar', arabicName: 'العصر', time: '15:30', icon: Icons.wb_sunny_outlined, hour: 15, minute: 30),
  PrayerTime(name: 'Maghrib', arabicName: 'المغرب', time: '18:05', icon: Icons.wb_twilight_rounded, hour: 18, minute: 5),
  PrayerTime(name: 'Isya', arabicName: 'العشاء', time: '19:18', icon: Icons.nights_stay_rounded, hour: 19, minute: 18),
];

/// Show the prayer tracking bottom sheet for a given date.
void showPrayerTrackingSheet(
  BuildContext context, {
  DateTime? date,
  Map<String, PrayerStatus>? statuses,
  int? prayerCount,
  ValueChanged<Map<String, PrayerStatus>>? onSave,
  ValueChanged<int>? onPointsEarned,
  ValueChanged<PrayerSaveResult>? onPrayerSaved,
  String? initialWakeUpTime,
  List<String> initialDeeds = const [],
}) {
  HapticFeedback.mediumImpact();

  Map<String, PrayerStatus> effectiveStatuses;
  if (statuses != null) {
    effectiveStatuses = Map.from(statuses);
  } else if (prayerCount != null) {
    effectiveStatuses = {};
    for (int i = 0; i < defaultPrayers.length; i++) {
      effectiveStatuses[defaultPrayers[i].name] =
          i < prayerCount ? PrayerStatus.done : PrayerStatus.upcoming;
    }
  } else {
    effectiveStatuses = {};
    for (final p in defaultPrayers) {
      effectiveStatuses[p.name] = PrayerStatus.upcoming;
    }
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PrayerTrackingSheet(
      prayers: defaultPrayers,
      statuses: effectiveStatuses,
      date: date,
      initialEditing: false,
      initialWakeUpTime: initialWakeUpTime,
      initialDeeds: initialDeeds,
      onSave: onSave ?? (_) {},
      onPointsEarned: onPointsEarned,
      onPrayerSaved: onPrayerSaved,
    ),
  );
}

/// Tampilkan bottom sheet blokir saat user mencoba klik tanggal di masa depan.
void showFutureDateBlockedSheet(BuildContext context, DateTime date) {
  HapticFeedback.heavyImpact();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _FutureDateBlockedSheet(date: date),
  );
}

/// ─── Bottom Sheet: Tanggal Masa Depan ─────────────────────────────────────
class _FutureDateBlockedSheet extends StatelessWidget {
  final DateTime date;
  const _FutureDateBlockedSheet({required this.date});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 40),
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


          // Main Message
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                // Emoji illustration
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppTheme.grey100,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.grey200,
                      width: 1.5,
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      '🤔',
                      style: TextStyle(fontSize: 32),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                const Text(
                  'Yakin besok kamu masih idup?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.5,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),

                // Sub message
                Text(
                  'Kamu tidak diperkenankan merekap\nkegiatan ibadah pada waktu kedepannya,\numur ga ada yang tau.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.grey600,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 32),

                // Close button
                SizedBox(
                  width: double.infinity,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: AppTheme.mainGradient,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: AppTheme.greenGlow,
                    ),
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: AppTheme.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Oke, aku paham 🙏',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ───── Main Widget ─────
class PrayerCountdown extends StatefulWidget {
  final ValueChanged<int>? onPointsEarned;
  final ValueChanged<PrayerSaveResult>? onPrayerSaved;
  final int streak;

  const PrayerCountdown({
    super.key,
    this.onPointsEarned,
    this.onPrayerSaved,
    this.streak = 0,
  });

  @override
  State<PrayerCountdown> createState() => _PrayerCountdownState();
}

class _PrayerCountdownState extends State<PrayerCountdown>
    with TickerProviderStateMixin {
  late Timer _timer;
  late AnimationController _pulseController;

  // Daftar waktu shalat (bisa diganti dengan data API nanti)
  static const List<PrayerTime> _prayers = [
    PrayerTime(
      name: 'Subuh',
      arabicName: 'الفجر',
      time: '04:38',
      icon: Icons.wb_twilight_rounded,
      hour: 4,
      minute: 38,
    ),
    PrayerTime(
      name: 'Dzuhur',
      arabicName: 'الظهر',
      time: '12:15',
      icon: Icons.wb_sunny_rounded,
      hour: 12,
      minute: 15,
    ),
    PrayerTime(
      name: 'Ashar',
      arabicName: 'العصر',
      time: '15:30',
      icon: Icons.wb_sunny_outlined,
      hour: 15,
      minute: 30,
    ),
    PrayerTime(
      name: 'Maghrib',
      arabicName: 'المغرب',
      time: '18:05',
      icon: Icons.wb_twilight_rounded,
      hour: 18,
      minute: 5,
    ),
    PrayerTime(
      name: 'Isya',
      arabicName: 'العشاء',
      time: '19:18',
      icon: Icons.nights_stay_rounded,
      hour: 19,
      minute: 18,
    ),
  ];

  // Status shalat hari ini dari database
  Map<String, PrayerStatus> _prayerStatuses = {};
  bool _isLoadingPrayers = true;

  // Saved extras dari database
  String? _savedWakeUpTime;
  List<String> _savedDeeds = [];

  int _nextPrayerIndex = 0;
  Duration _remainingTime = Duration.zero;
  Duration _totalDuration = Duration.zero;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _initStatuses();
    _loadPrayerStatusesFromDB();
    _calculateNextPrayer();
    _startTimer();
  }

  void _initStatuses() {
    // Default: semua upcoming sampai data dari DB dimuat
    for (final p in _prayers) {
      _prayerStatuses[p.name] = PrayerStatus.upcoming;
    }
  }

  /// Muat status shalat hari ini dari database
  Future<void> _loadPrayerStatusesFromDB() async {
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final data = await PrayerService.getPrayersByDate(today);

      if (!mounted) return;
      setState(() {
        for (final entry in data.prayers.entries) {
          switch (entry.value.status) {
            case 'done':
              _prayerStatuses[entry.key] = PrayerStatus.done;
              break;
            case 'done_jamaah':
              _prayerStatuses[entry.key] = PrayerStatus.doneJamaah;
              break;
            default:
              _prayerStatuses[entry.key] = PrayerStatus.upcoming;
          }
        }
        // Simpan extras dari server
        _savedWakeUpTime = data.wakeUpTime;
        _savedDeeds = List.from(data.deeds);
        _isLoadingPrayers = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingPrayers = false);
      debugPrint('Gagal load prayer statuses: $e');
    }
  }

  /// Public method untuk refresh data (dipanggil dari parent)
  Future<void> refreshData() async {
    setState(() => _isLoadingPrayers = true);
    await _loadPrayerStatusesFromDB();
  }

  void _calculateNextPrayer() {
    final now = DateTime.now();
    for (int i = 0; i < _prayers.length; i++) {
      final p = _prayers[i];
      final prayerTime =
          DateTime(now.year, now.month, now.day, p.hour, p.minute);
      if (prayerTime.isAfter(now)) {
        _nextPrayerIndex = i;
        _remainingTime = prayerTime.difference(now);

        if (i > 0) {
          final prev = _prayers[i - 1];
          final prevTime =
              DateTime(now.year, now.month, now.day, prev.hour, prev.minute);
          _totalDuration = prayerTime.difference(prevTime);
        } else {
          _totalDuration = const Duration(hours: 5);
        }
        return;
      }
    }
    // Semua shalat hari ini sudah lewat, tunggu subuh besok
    _nextPrayerIndex = 0;
    final tomorrow = DateTime(
        now.year, now.month, now.day + 1, _prayers[0].hour, _prayers[0].minute);
    _remainingTime = tomorrow.difference(now);
    _totalDuration = const Duration(hours: 8);
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_remainingTime.inSeconds > 0) {
          _remainingTime -= const Duration(seconds: 1);
        } else {
          _calculateNextPrayer();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  // ───── Bottom Sheet ─────
  void _showPrayerTrackingSheet() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PrayerTrackingSheet(
        prayers: _prayers,
        statuses: Map.from(_prayerStatuses),
        initialEditing: true,
        initialWakeUpTime: _savedWakeUpTime,
        initialDeeds: _savedDeeds,
        onSave: (updatedStatuses) {
          setState(() {
            _prayerStatuses = updatedStatuses;
          });
        },
        onPointsEarned: widget.onPointsEarned,
        onPrayerSaved: (result) {
          // Reload data dari server agar extras terbaru tersimpan
          _loadPrayerStatusesFromDB();
          widget.onPrayerSaved?.call(result);
        },
      ),
    );
  }

  // ───── Build ─────
  @override
  Widget build(BuildContext context) {
    final nextPrayer = _prayers[_nextPrayerIndex];
    final elapsed = _totalDuration - _remainingTime;
    final progress =
        (elapsed.inSeconds / _totalDuration.inSeconds).clamp(0.0, 1.0);

    final doneCount = _prayerStatuses.values
        .where((s) => s == PrayerStatus.done || s == PrayerStatus.doneJamaah)
        .length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          children: [
              // ── Top section: countdown ──
              _buildCountdownSection(nextPrayer, progress),

              // ── Divider ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Divider(
                  color: AppTheme.grey100,
                  height: 1,
                  thickness: 1,
                ),
              ),

              // ── Bottom section: prayer status strip ──
              _buildPrayerStatusStrip(doneCount),
            ],
          ),
      ),
    );
  }

  // ── Countdown Section ──
  Widget _buildCountdownSection(PrayerTime nextPrayer, double progress) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Row(
        children: [
          // Mini circular progress
          _buildMiniProgress(progress, nextPrayer),
          const SizedBox(width: 16),

          // Text info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Menuju',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.grey400,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      nextPrayer.name,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.grey400,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Timer
                Text(
                  _fmt(_remainingTime),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                    fontFeatures: [FontFeature.tabularFigures()],
                    letterSpacing: 1.5,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),

                // Waktu adzan
                Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 12,
                      color: AppTheme.grey400,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Adzan ${nextPrayer.name} — ${nextPrayer.time} WIB',
                      style: TextStyle(
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
        ],
      ),
    );
  }

  // ── Mini circular progress ──
  Widget _buildMiniProgress(double progress, PrayerTime prayer) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final glow = 0.1 + _pulseController.value * 0.15;
        return Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryGreen.withOpacity(glow),
                blurRadius: 20,
                spreadRadius: 0,
              ),
            ],
          ),
          child: child,
        );
      },
      child: SizedBox(
        width: 68,
        height: 68,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 68,
              height: 68,
              child: CustomPaint(
                painter: _MiniProgressPainter(
                  progress: progress,
                  bgColor: AppTheme.grey100,
                  gradient: AppTheme.mainGradient,
                ),
              ),
            ),
            Icon(
              prayer.icon,
              size: 24,
              color: AppTheme.primaryGreen,
            ),
          ],
        ),
      ),
    );
  }

  // ── Prayer status strip (5 shalat) ──
  Widget _buildPrayerStatusStrip(int doneCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subheader with streak
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Row(
              children: [
                Text(
                  'PENCAPAIANMU',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.grey400,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEA580C).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.local_fire_department_rounded,
                        color: const Color(0xFFEA580C),
                        size: 12,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${widget.streak} Hari Streak',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFEA580C),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 5 prayer pills
          Row(
            children: List.generate(_prayers.length, (i) {
              final p = _prayers[i];
              final status = _prayerStatuses[p.name] ?? PrayerStatus.upcoming;
              final isDone = status == PrayerStatus.done ||
                  status == PrayerStatus.doneJamaah;
              final isNext = i == _nextPrayerIndex;

              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    gradient: isNext ? AppTheme.mainGradient : null,
                    color: isDone
                        ? AppTheme.emerald.withOpacity(0.15)
                        : isNext
                            ? null
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: !isDone && !isNext
                        ? Border.all(color: AppTheme.grey100, width: 1)
                        : null,
                  ),
                  child: Column(
                    children: [
                      if (isDone)
                        Icon(
                          status == PrayerStatus.doneJamaah
                              ? Icons.groups_rounded
                              : Icons.check_circle_rounded,
                          size: 12,
                          color: AppTheme.primaryGreen,
                        )
                      else
                        Icon(
                          isNext
                              ? Icons.arrow_forward_rounded
                              : Icons.circle_outlined,
                          size: 12,
                          color: isNext ? AppTheme.white : AppTheme.grey200,
                        ),
                      const SizedBox(height: 2),
                      Text(
                        _shortName(p.name),
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          color: isNext
                              ? AppTheme.white
                              : isDone
                                  ? AppTheme.primaryGreen
                                  : AppTheme.grey400,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),

          const SizedBox(height: 10),

          // REKAP button
          GestureDetector(
            onTap: _showPrayerTrackingSheet,
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                gradient: AppTheme.mainGradient,
                borderRadius: BorderRadius.circular(10),
                boxShadow: AppTheme.greenGlow,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.edit_note_rounded,
                    size: 14,
                    color: AppTheme.white,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'REKAP',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.white,
                      letterSpacing: 1.5,
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

  String _shortName(String name) {
    const map = {
      'Subuh': 'SBH',
      'Dzuhur': 'DZR',
      'Ashar': 'ASR',
      'Maghrib': 'MGR',
      'Isya': 'ISY',
    };
    return map[name] ?? name;
  }

  String _fmt(Duration d) {
    String t(int n) => n.toString().padLeft(2, '0');
    return '${t(d.inHours)}:${t(d.inMinutes.remainder(60))}:${t(d.inSeconds.remainder(60))}';
  }
}

// ───── Mini progress ring painter ─────
class _MiniProgressPainter extends CustomPainter {
  final double progress;
  final Color bgColor;
  final Gradient gradient;

  _MiniProgressPainter({
    required this.progress,
    required this.bgColor,
    required this.gradient,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) / 2) - 6;
    const stroke = 5.0;

    final bgPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    if (progress > 0.005) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      final arcPaint = Paint()
        ..shader = gradient.createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
          rect, -math.pi / 2, 2 * math.pi * progress, false, arcPaint);
    }
  }

  @override
  bool shouldRepaint(_MiniProgressPainter old) => old.progress != progress;
}

// ═══════════════════════════════════════════════════════
// ───── Bottom Sheet: Prayer Tracking ─────
// ═══════════════════════════════════════════════════════

class _PrayerTrackingSheet extends StatefulWidget {
  final List<PrayerTime> prayers;
  final Map<String, PrayerStatus> statuses;
  final ValueChanged<Map<String, PrayerStatus>> onSave;
  final ValueChanged<int>? onPointsEarned;
  final ValueChanged<PrayerSaveResult>? onPrayerSaved;
  final DateTime? date;
  final bool initialEditing;
  final String? initialWakeUpTime;
  final List<String> initialDeeds;

  const _PrayerTrackingSheet({
    required this.prayers,
    required this.statuses,
    required this.onSave,
    this.onPointsEarned,
    this.onPrayerSaved,
    this.date,
    this.initialEditing = false,
    this.initialWakeUpTime,
    this.initialDeeds = const [],
  });

  @override
  State<_PrayerTrackingSheet> createState() => _PrayerTrackingSheetState();
}

class _PrayerTrackingSheetState extends State<_PrayerTrackingSheet>
    with SingleTickerProviderStateMixin {
  late Map<String, PrayerStatus> _statuses;
  late Map<String, PrayerStatus> _originalStatuses; // status awal sebelum edit
  late AnimationController _animController;
  bool _isEditing = false;
  bool _isSaving = false;
  LocationData? _currentLocation;
  String? _locationError;

  // Wake-up time
  String? _selectedWakeUpTime;

  // Good deeds
  static const List<String> _defaultDeeds = [
    'Tahajjud',
    'Shadaqah',
    'Tadarus',
    'Dzikir Pagi',
    'Dhuha',
    'Puasa Sunnah',
    'Silaturahmi',
  ];
  final Set<String> _selectedDeeds = {};
  final List<String> _customDeeds = [];

  @override
  void initState() {
    super.initState();
    _statuses = Map.from(widget.statuses);
    _originalStatuses = Map.from(widget.statuses); // simpan salinan asli
    _isEditing = widget.initialEditing;

    // Restore saved wake-up time & deeds
    _selectedWakeUpTime = widget.initialWakeUpTime;
    if (widget.initialDeeds.isNotEmpty) {
      _selectedDeeds.addAll(widget.initialDeeds);
      // Tambahkan custom deeds yang bukan default ke daftar custom
      for (final deed in widget.initialDeeds) {
        if (!_defaultDeeds.contains(deed)) {
          _customDeeds.add(deed);
        }
      }
    }

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();

    // Ambil lokasi GPS saat sheet dibuka
    _fetchLocation();

    // Jika belum ada data extras, load dari server
    if (widget.initialWakeUpTime == null && widget.initialDeeds.isEmpty) {
      _loadExtrasFromServer();
    }
  }

  /// Load wake-up time & deeds dari server untuk tanggal ini
  Future<void> _loadExtrasFromServer() async {
    try {
      final date = widget.date != null
          ? DateFormat('yyyy-MM-dd').format(widget.date!)
          : DateFormat('yyyy-MM-dd').format(DateTime.now());
      final data = await PrayerService.getPrayersByDate(date);
      if (!mounted) return;
      setState(() {
        if (data.wakeUpTime != null && data.wakeUpTime!.isNotEmpty) {
          _selectedWakeUpTime = data.wakeUpTime;
        }
        if (data.deeds.isNotEmpty) {
          _selectedDeeds.addAll(data.deeds);
          for (final deed in data.deeds) {
            if (!_defaultDeeds.contains(deed) && !_customDeeds.contains(deed)) {
              _customDeeds.add(deed);
            }
          }
        }
      });
    } catch (e) {
      debugPrint('Gagal load extras: $e');
    }
  }

  /// Ambil lokasi GPS siswa untuk tracking shalat
  Future<void> _fetchLocation() async {
    try {
      _currentLocation = await LocationService.getCurrentLocation();
    } catch (e) {
      _locationError = e.toString();
      debugPrint('GPS error: $_locationError');
    }
  }

  /// Simpan rekap shalat ke server + kirim lokasi GPS
  Future<void> _saveToServer() async {
    HapticFeedback.lightImpact();
    setState(() => _isSaving = true);

    // Bangun data prayer entries dengan lokasi GPS
    final prayers = <String, PrayerEntry>{};
    _statuses.forEach((name, status) {
      String statusStr;
      switch (status) {
        case PrayerStatus.done:
          statusStr = 'done';
          break;
        case PrayerStatus.doneJamaah:
          statusStr = 'done_jamaah';
          break;
        default:
          statusStr = 'missed';
      }

      prayers[name] = PrayerEntry(
        status: statusStr,
        latitude: _currentLocation?.latitude,
        longitude: _currentLocation?.longitude,
      );
    });

    // Tentukan tanggal
    final date = widget.date != null
        ? DateFormat('yyyy-MM-dd').format(widget.date!)
        : DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Hitung poin lokal sebagai fallback — hanya SELISIH dari status awal
    int localEarnedPoints = 0;

    // Hitung poin pada status baru
    int newPoints = 0;
    for (final s in _statuses.values) {
      if (s == PrayerStatus.done) newPoints += 1;
      if (s == PrayerStatus.doneJamaah) newPoints += 2;
    }
    final newDoneCount = _statuses.values
        .where((s) => s == PrayerStatus.done || s == PrayerStatus.doneJamaah)
        .length;
    if (newDoneCount >= 5) newPoints += 3;

    // Hitung poin pada status lama
    int oldPoints = 0;
    for (final s in _originalStatuses.values) {
      if (s == PrayerStatus.done) oldPoints += 1;
      if (s == PrayerStatus.doneJamaah) oldPoints += 2;
    }
    final oldDoneCount = _originalStatuses.values
        .where((s) => s == PrayerStatus.done || s == PrayerStatus.doneJamaah)
        .length;
    if (oldDoneCount >= 5) oldPoints += 3;

    // Delta = hanya poin yang bertambah
    localEarnedPoints = (newPoints - oldPoints).clamp(0, 999);

    // Tambah wake-up & deeds hanya jika belum pernah dihitung
    final hasWakeUp = _selectedWakeUpTime == '03:00' || _selectedWakeUpTime == '04:00';
    if (hasWakeUp) {
      localEarnedPoints += 1;
    }
    localEarnedPoints += _selectedDeeds.length;

    // Combo bonus: jika wake-up DAN deeds keduanya diisi
    if (hasWakeUp && _selectedDeeds.isNotEmpty) {
      localEarnedPoints += 3;
    }

    try {
      // Kirim ke server
      final result = await PrayerService.savePrayers(
        date: date,
        prayers: prayers,
        wakeUpTime: _selectedWakeUpTime,
        deeds: _selectedDeeds.toList(),
      );

      if (!mounted) return;

      // Update UI lokal
      widget.onSave(_statuses);

      // Close bottom sheet
      Navigator.of(context).pop();

      // Trigger point animation dari server
      if (result.earnedPoints > 0 && widget.onPointsEarned != null) {
        widget.onPointsEarned!(result.earnedPoints);
      }

      // Callback dengan data dari server
      if (widget.onPrayerSaved != null) {
        widget.onPrayerSaved!(result);
      }
    } catch (e) {
      if (!mounted) return;

      // Server gagal → tetap simpan lokal & tutup bottom sheet
      widget.onSave(_statuses);
      Navigator.of(context).pop();

      // Trigger point animation dari hitungan lokal
      if (localEarnedPoints > 0 && widget.onPointsEarned != null) {
        widget.onPointsEarned!(localEarnedPoints);
      }

      // Tampilkan peringatan bahwa data belum tersinkron
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Tersimpan lokal. Akan disinkron saat online.'),
              backgroundColor: const Color(0xFFD97706),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  int get _doneCount => _statuses.values
      .where((s) => s == PrayerStatus.done || s == PrayerStatus.doneJamaah)
      .length;

  List<String> get _allDeeds => [..._defaultDeeds, ..._customDeeds];

  // ── Open custom time picker ──
  void _openCustomTimePicker() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CustomTimePickerSheet(),
    );
    if (result != null && mounted) {
      setState(() => _selectedWakeUpTime = result);
    }
  }

  // ── Open custom deed input ──
  void _openCustomDeedInput() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CustomDeedInputSheet(),
    );
    if (result != null && result.trim().isNotEmpty && mounted) {
      setState(() {
        _customDeeds.add(result.trim());
        _selectedDeeds.add(result.trim());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewPadding.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.85;

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
                    Icons.mosque_rounded,
                    color: AppTheme.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.date != null &&
                                !DateUtils.isSameDay(
                                    widget.date!, DateTime.now())
                            ? 'Rekap Shalat'
                            : 'Rekap Shalat Hari Ini',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.date != null &&
                                !DateUtils.isSameDay(
                                    widget.date!, DateTime.now())
                            ? DateFormat('EEEE, d MMMM yyyy', 'id_ID')
                                .format(widget.date!)
                            : 'Tap untuk mengubah status shalat',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.grey400,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Scrollable content
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Wake-up time section (selalu interaktif) ──
                  _buildWakeUpTimeSection(),

                  const SizedBox(height: 8),

                  // Prayer list (hanya aktif saat editing)
                  AnimatedOpacity(
                    opacity: _isEditing ? 1.0 : 0.6,
                    duration: const Duration(milliseconds: 300),
                    child: IgnorePointer(
                      ignoring: !_isEditing,
                      child: Column(
                        children: List.generate(widget.prayers.length, (i) {
                          final delay = i * 0.08;
                          return AnimatedBuilder(
                            animation: _animController,
                            builder: (context, child) {
                              final t = Curves.easeOutCubic.transform(
                                ((_animController.value - delay) / (1 - delay))
                                    .clamp(0.0, 1.0),
                              );
                              return Transform.translate(
                                offset: Offset(0, 20 * (1 - t)),
                                child: Opacity(opacity: t, child: child),
                              );
                            },
                            child: _buildPrayerRow(widget.prayers[i]),
                          );
                        }),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Good deeds section (selalu interaktif) ──
                  _buildGoodDeedsSection(),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // Edit / Save button (fixed at bottom)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: _isEditing
                  ? ElevatedButton(
                      onPressed: _isSaving ? null : _saveToServer,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                      ),
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: AppTheme.mainGradient,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: AppTheme.greenGlow,
                        ),
                        child: Container(
                          alignment: Alignment.center,
                          child: _isSaving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: AppTheme.white,
                                  ),
                                )
                              : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.save_rounded,
                                  color: AppTheme.white, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Simpan Rekap',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.white,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : OutlinedButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        setState(() => _isEditing = true);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        side: const BorderSide(
                          color: AppTheme.primaryGreen,
                          width: 1.5,
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.edit_rounded,
                              color: AppTheme.primaryGreen, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Edit Rekap',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryGreen,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),

          SizedBox(height: 16 + bottomPad),
        ],
      ),
    );
  }

  // ── Wake-up Time Section ──
  Widget _buildWakeUpTimeSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.offWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.grey100, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Kamu Bangun jam berapa?',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                if (_selectedWakeUpTime != null)
                  GestureDetector(
                    onTap: () => setState(() => _selectedWakeUpTime = null),
                    child: Icon(Icons.close_rounded,
                        size: 16, color: AppTheme.grey400),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildTimeChip('03:00'),
                const SizedBox(width: 8),
                _buildTimeChip('04:00'),
                const SizedBox(width: 8),
                _buildTimeChip('05:00'),
                const SizedBox(width: 8),
                _buildCustomTimeChip(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeChip(String time) {
    final isSelected = _selectedWakeUpTime == time;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedWakeUpTime = isSelected ? null : time);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: isSelected ? AppTheme.mainGradient : null,
            color: isSelected ? null : AppTheme.white,
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? null
                : Border.all(color: AppTheme.grey200, width: 1),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.primaryGreen.withOpacity(0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              time,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isSelected ? AppTheme.white : AppTheme.grey600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomTimeChip() {
    // Check if selected time is a custom one (not one of the presets)
    final isCustomSelected = _selectedWakeUpTime != null &&
        _selectedWakeUpTime != '03:00' &&
        _selectedWakeUpTime != '04:00' &&
        _selectedWakeUpTime != '05:00';

    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          _openCustomTimePicker();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: isCustomSelected ? AppTheme.mainGradient : null,
            color: isCustomSelected ? null : AppTheme.white,
            borderRadius: BorderRadius.circular(12),
            border: isCustomSelected
                ? null
                : Border.all(color: AppTheme.grey200, width: 1),
            boxShadow: isCustomSelected
                ? [
                    BoxShadow(
                      color: AppTheme.primaryGreen.withOpacity(0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              isCustomSelected ? _selectedWakeUpTime! : 'Kustom',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color:
                    isCustomSelected ? AppTheme.white : AppTheme.grey600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Good Deeds Section ──
  Widget _buildGoodDeedsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.offWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.grey100, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Hal kebaikan apa lagi yang kamu lakukan?',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._allDeeds.map((deed) => _buildDeedChip(deed)),
                _buildAddDeedChip(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeedChip(String deed) {
    final isSelected = _selectedDeeds.contains(deed);
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          if (isSelected) {
            _selectedDeeds.remove(deed);
          } else {
            _selectedDeeds.add(deed);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected ? AppTheme.mainGradient : null,
          color: isSelected ? null : AppTheme.white,
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? null
              : Border.all(color: AppTheme.grey200, width: 1),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryGreen.withOpacity(0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              const Icon(Icons.check_rounded,
                  size: 14, color: AppTheme.white),
              const SizedBox(width: 4),
            ],
            Text(
              deed,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? AppTheme.white : AppTheme.grey600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddDeedChip() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _openCustomDeedInput();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.primaryGreen.withOpacity(0.4),
            width: 1.5,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded,
                size: 14, color: AppTheme.primaryGreen),
            const SizedBox(width: 4),
            Text(
              'Lainnya',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrayerRow(PrayerTime prayer) {
    final status = _statuses[prayer.name] ?? PrayerStatus.upcoming;
    final isDone =
        status == PrayerStatus.done || status == PrayerStatus.doneJamaah;
    final isJamaah = status == PrayerStatus.doneJamaah;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              // Cycle: upcoming -> done -> doneJamaah -> upcoming
              if (status == PrayerStatus.upcoming) {
                _statuses[prayer.name] = PrayerStatus.done;
              } else if (status == PrayerStatus.done) {
                _statuses[prayer.name] = PrayerStatus.doneJamaah;
              } else {
                _statuses[prayer.name] = PrayerStatus.upcoming;
              }
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isDone
                  ? AppTheme.emerald.withOpacity(0.08)
                  : AppTheme.offWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDone
                    ? AppTheme.emerald.withOpacity(0.3)
                    : AppTheme.grey100,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Status icon
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: isDone ? AppTheme.mainGradient : null,
                    color: isDone ? null : AppTheme.grey100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isDone ? Icons.check_rounded : prayer.icon,
                    size: 20,
                    color: isDone ? AppTheme.white : AppTheme.grey400,
                  ),
                ),
                const SizedBox(width: 14),

                // Prayer info
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
                              color: isDone
                                  ? AppTheme.primaryGreen
                                  : AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        prayer.time,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.grey400,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // Status badge + point indicator
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Point badge
                    if (isDone)
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: AppTheme.mainGradient,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isJamaah ? '+2 Poin' : '+1 Poin',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.white,
                          ),
                        ),
                      ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isDone
                            ? (isJamaah
                                ? AppTheme.primaryGreen.withOpacity(0.12)
                                : AppTheme.emerald.withOpacity(0.15))
                            : AppTheme.grey100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isJamaah)
                            const Icon(Icons.groups_rounded,
                                size: 14, color: AppTheme.primaryGreen)
                          else if (isDone)
                            const Icon(Icons.check_circle_rounded,
                                size: 14, color: AppTheme.emerald)
                          else
                            Icon(Icons.circle_outlined,
                                size: 14, color: AppTheme.grey400),
                          const SizedBox(width: 4),
                          Text(
                            isJamaah
                                ? "Jama'ah"
                                : isDone
                                    ? 'Sendiri'
                                    : 'Belum',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isDone
                                  ? AppTheme.primaryGreen
                                  : AppTheme.grey400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// ───── Bottom Sheet: Custom Time Picker ─────
// ═══════════════════════════════════════════════════════

class _CustomTimePickerSheet extends StatefulWidget {
  const _CustomTimePickerSheet();

  @override
  State<_CustomTimePickerSheet> createState() => _CustomTimePickerSheetState();
}

class _CustomTimePickerSheetState extends State<_CustomTimePickerSheet> {
  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;
  int _selectedHour = 4;
  int _selectedMinute = 0;

  @override
  void initState() {
    super.initState();
    _hourController = FixedExtentScrollController(initialItem: _selectedHour);
    _minuteController =
        FixedExtentScrollController(initialItem: _selectedMinute);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  String _fmt(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewPadding.bottom;

    return Container(
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
                    Icons.access_time_rounded,
                    color: AppTheme.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pilih Jam Bangun',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Geser untuk memilih waktu',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.grey400,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Time picker wheels
          SizedBox(
            height: 180,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Hour wheel
                SizedBox(
                  width: 80,
                  child: ListWheelScrollView.useDelegate(
                    controller: _hourController,
                    itemExtent: 50,
                    physics: const FixedExtentScrollPhysics(),
                    diameterRatio: 1.5,
                    perspective: 0.003,
                    onSelectedItemChanged: (index) {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedHour = index);
                    },
                    childDelegate: ListWheelChildBuilderDelegate(
                      childCount: 24,
                      builder: (context, index) {
                        final isSelected = index == _selectedHour;
                        return Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: TextStyle(
                              fontSize: isSelected ? 32 : 20,
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                              color: isSelected
                                  ? AppTheme.primaryGreen
                                  : AppTheme.grey400,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                            child: Text(_fmt(index)),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // Separator
                const Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Text(
                    ':',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),

                // Minute wheel
                SizedBox(
                  width: 80,
                  child: ListWheelScrollView.useDelegate(
                    controller: _minuteController,
                    itemExtent: 50,
                    physics: const FixedExtentScrollPhysics(),
                    diameterRatio: 1.5,
                    perspective: 0.003,
                    onSelectedItemChanged: (index) {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedMinute = index);
                    },
                    childDelegate: ListWheelChildBuilderDelegate(
                      childCount: 60,
                      builder: (context, index) {
                        final isSelected = index == _selectedMinute;
                        return Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: TextStyle(
                              fontSize: isSelected ? 32 : 20,
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                              color: isSelected
                                  ? AppTheme.primaryGreen
                                  : AppTheme.grey400,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                            child: Text(_fmt(index)),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Selected time preview
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.emerald.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '${_fmt(_selectedHour)}:${_fmt(_selectedMinute)}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryGreen,
                  fontFeatures: [FontFeature.tabularFigures()],
                  letterSpacing: 2,
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Confirm button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  final time =
                      '${_fmt(_selectedHour)}:${_fmt(_selectedMinute)}';
                  Navigator.pop(context, time);
                  HapticFeedback.lightImpact();
                },
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                ),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: AppTheme.mainGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: AppTheme.greenGlow,
                  ),
                  child: Container(
                    alignment: Alignment.center,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_rounded,
                            color: AppTheme.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Pilih Waktu Ini',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          SizedBox(height: 16 + bottomPad),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// ───── Bottom Sheet: Custom Deed Input ─────
// ═══════════════════════════════════════════════════════

class _CustomDeedInputSheet extends StatefulWidget {
  const _CustomDeedInputSheet();

  @override
  State<_CustomDeedInputSheet> createState() => _CustomDeedInputSheetState();
}

class _CustomDeedInputSheetState extends State<_CustomDeedInputSheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() => _isValid = _controller.text.trim().isNotEmpty);
    });
    // Auto-focus the text field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    if (_isValid) {
      Navigator.pop(context, _controller.text.trim());
      HapticFeedback.lightImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomPad = MediaQuery.of(context).viewPadding.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
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
                      Icons.add_circle_rounded,
                      color: AppTheme.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tambah Kebaikan',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Tulis hal baik yang kamu lakukan',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.grey400,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Text field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Contoh: Membantu tetangga',
                  hintStyle: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.grey400,
                  ),
                  filled: true,
                  fillColor: AppTheme.offWhite,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide:
                        BorderSide(color: AppTheme.grey200, width: 1),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide:
                        BorderSide(color: AppTheme.grey200, width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                        color: AppTheme.primaryGreen, width: 1.5),
                  ),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 16, right: 8),
                    child: Icon(Icons.edit_rounded,
                        size: 18, color: AppTheme.grey400),
                  ),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 0, minHeight: 0),
                ),
                onSubmitted: (_) => _submit(),
              ),
            ),

            const SizedBox(height: 20),

            // Submit button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isValid ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    disabledBackgroundColor: AppTheme.grey100,
                  ),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient:
                          _isValid ? AppTheme.mainGradient : null,
                      color: _isValid ? null : AppTheme.grey100,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: _isValid ? AppTheme.greenGlow : null,
                    ),
                    child: Container(
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_rounded,
                              color: _isValid
                                  ? AppTheme.white
                                  : AppTheme.grey400,
                              size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Tambahkan',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _isValid
                                  ? AppTheme.white
                                  : AppTheme.grey400,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            SizedBox(height: 16 + bottomPad),
          ],
        ),
      ),
    );
  }
}
