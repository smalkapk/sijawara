import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme.dart';
import '../services/wali_service.dart';
import '../services/evaluasi_view_service.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/evaluasi_result_card.dart';

class WaliLivePage extends StatefulWidget {
  const WaliLivePage({super.key, this.studentId});

  /// ID siswa aktif yang dipilih dari WaliHomePage.
  final int? studentId;

  @override
  State<WaliLivePage> createState() => _WaliLivePageState();
}

class _WaliLivePageState extends State<WaliLivePage> {
  // ── State ──
  WaliLiveTimelineData? _data;
  bool _isLoading = true;
  String? _errorMessage;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadTimeline();
  }

  @override
  void didUpdateWidget(covariant WaliLivePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.studentId != widget.studentId) {
      _selectedDate = DateTime.now();
      _loadTimeline();
    }
  }

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  Future<void> _loadTimeline() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    try {
      final data = await WaliService.getLiveTimeline(
        studentId: widget.studentId,
        date: dateStr,
      );
      if (mounted) {
        setState(() {
          _data = data;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: _isLoading
                  ? _buildLoadingState()
                  : _errorMessage != null
                      ? _buildErrorState()
                      : _buildContent(),
            ),
          ],
        ),
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

          // Skeleton Student Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SkeletonLoader(
              height: 160,
              width: double.infinity,
              borderRadius: BorderRadius.circular(16),
            ),
          ),

          const SizedBox(height: 20),

          // Skeleton Timeline Header Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonLoader(
                      height: 20,
                      width: 140,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    const SizedBox(height: 8),
                    SkeletonLoader(
                      height: 14,
                      width: 100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
                SkeletonLoader(
                  height: 40,
                  width: 40,
                  borderRadius: BorderRadius.circular(12),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Skeleton Timeline Items List
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                boxShadow: AppTheme.softShadow,
              ),
              child: Column(
                children: List.generate(3, (index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonLoader(
                          height: 28,
                          width: 28,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SkeletonLoader(
                                height: 16,
                                width: double.infinity,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              const SizedBox(height: 6),
                              SkeletonLoader(
                                height: 16,
                                width: 200,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              const SizedBox(height: 10),
                              SkeletonLoader(
                                height: 12,
                                width: 60,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: AppTheme.grey400,
            ),
            const SizedBox(height: 14),
            Text(
              _errorMessage ?? 'Terjadi kesalahan',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => _loadTimeline(),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba Lagi'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primaryGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final data = _data;
    if (data == null) return const SizedBox.shrink();

    return RefreshIndicator(
      onRefresh: () => _loadTimeline(),
      color: AppTheme.primaryGreen,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            // Student card
            _buildStudentCard(data),

            const SizedBox(height: 20),

            // Timeline section
            _buildTimelineSection(context, data),

            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }

  // ── Header ──
  Widget _buildHeader(BuildContext context) {
    final isOnline = _data?.summary.isOnline ?? false;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isOnline ? AppTheme.emerald : AppTheme.grey400,
                  boxShadow: isOnline
                      ? [
                          BoxShadow(
                            color: AppTheme.emerald.withOpacity(0.5),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Live Tracking',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.primaryGreen,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const Spacer(),
              if (!_isLoading)
                GestureDetector(
                  onTap: () => _loadTimeline(),
                  child: Icon(
                    Icons.refresh_rounded,
                    size: 20,
                    color: AppTheme.grey400,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Aktivitas Siswa',
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

  // ── Student mini card ──
  Widget _buildStudentCard(WaliLiveTimelineData data) {
    final child = data.selectedChild;
    if (child == null) return const SizedBox.shrink();

    final summary = data.summary;
    final isOnline = summary.isOnline;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: AppTheme.mainGradient,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          boxShadow: AppTheme.greenGlow,
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      child.initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        child.studentName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Kelas ${child.className} · ${summary.prayersDone}/${summary.prayersTotal} Shalat',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isOnline
                              ? AppTheme.softGold
                              : Colors.white.withOpacity(0.4),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isOnline ? 'Aktif' : 'Offline',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
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
    );
  }

  // ── Date Picker Bottomsheet ──
  void _pickDate() {
    final now = DateTime.now();
    DateTime tempDate = _selectedDate;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              decoration: const BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month_rounded,
                            size: 20, color: AppTheme.primaryGreen),
                        const SizedBox(width: 10),
                        Text(
                          'Pilih Tanggal',
                          style:
                              Theme.of(ctx).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const Spacer(),
                        // Tombol Hari Ini
                        GestureDetector(
                          onTap: () {
                            setSheetState(() => tempDate = now);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Text(
                              'Hari Ini',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryGreen,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Theme(
                    data: Theme.of(ctx).copyWith(
                      colorScheme: Theme.of(ctx).colorScheme.copyWith(
                        primary: AppTheme.primaryGreen,
                        onPrimary: Colors.white,
                        surface: AppTheme.white,
                        onSurface: AppTheme.textPrimary,
                      ),
                    ),
                    child: CalendarDatePicker(
                      initialDate: tempDate,
                      firstDate: DateTime(2024),
                      lastDate: now,
                      onDateChanged: (date) {
                        setSheetState(() => tempDate = date);
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          setState(() => _selectedDate = tempDate);
                          _loadTimeline();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Tampilkan',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Timeline section ──
  Widget _buildTimelineSection(
      BuildContext context, WaliLiveTimelineData data) {
    final timeline = data.timeline;

    // Format date display
    final days = [
      '', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'
    ];
    final months = [
      '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    final dateDisplay =
        '${days[_selectedDate.weekday]}, ${_selectedDate.day} ${months[_selectedDate.month]} ${_selectedDate.year}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isToday ? 'Timeline Hari Ini' : 'Timeline',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateDisplay,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _isToday
                        ? AppTheme.primaryGreen.withOpacity(0.08)
                        : AppTheme.primaryGreen,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.calendar_month_rounded,
                    size: 20,
                    color: _isToday ? AppTheme.primaryGreen : Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          if (timeline.isEmpty)
            _buildEmptyTimeline()
          else
            _buildFlatTimeline(timeline),
        ],
      ),
    );
  }

  Widget _buildEmptyTimeline() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        boxShadow: AppTheme.softShadow,
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.timeline_rounded,
              size: 48,
              color: AppTheme.grey200,
            ),
            const SizedBox(height: 12),
            Text(
              'Siswa tidak melaporkan apapun',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.grey400,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Aktivitas siswa akan muncul di sini',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.grey400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Flat timeline (newest first) ──
  Widget _buildFlatTimeline(List<WaliTimelineEvent> events) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        children: List.generate(events.length, (index) {
          final event = events[index];
          final isLast = index == events.length - 1;
          return _buildTimelineItem(
            event: event,
            showLine: !isLast,
          );
        }),
      ),
    );
  }

  // ── Icon & color based on event type ──

  /// Buka bottom-sheet evaluasi dari data yang tertanam di timeline event.
  void _openEvaluasiBottomSheet(WaliTimelineEvent event) {
    if (event.evaluasiData == null) return;
    final report = EvaluasiViewReport.fromJson(event.evaluasiData!);
    showEvaluasiBottomSheet(context, report);
  }

  IconData _getEventIcon(String type) {
    switch (type) {
      case 'shalat':
        return Icons.mosque_rounded;
      case 'puasa':
        return Icons.nights_stay_rounded;
      case 'bangun_pagi':
        return Icons.wb_sunny_rounded;
      case 'kebaikan':
        return Icons.volunteer_activism_rounded;
      case 'combo':
        return Icons.flash_on_rounded;
      case 'sedekah':
        return Icons.card_giftcard_rounded;
      case 'public_speaking':
        return Icons.record_voice_over_rounded;
      case 'kajian':
        return Icons.menu_book_rounded;
      case 'quran':
        return Icons.auto_stories_rounded;
      case 'tahfidz':
        return Icons.bookmark_rounded;
      case 'jurnal':
        return Icons.edit_note_rounded;
      case 'evaluasi':
        return Icons.assignment_turned_in_rounded;
      default:
        return Icons.circle;
    }
  }

  Color _getEventColor(String type) {
    switch (type) {
      case 'shalat':
        return AppTheme.primaryGreen;
      case 'puasa':
        return const Color(0xFF6366F1);
      case 'bangun_pagi':
        return const Color(0xFFF59E0B);
      case 'kebaikan':
        return const Color(0xFFEC4899);
      case 'combo':
        return const Color(0xFFEA580C);
      case 'sedekah':
        return const Color(0xFF14B8A6);
      case 'public_speaking':
        return const Color(0xFF8B5CF6);
      case 'kajian':
        return const Color(0xFF3B82F6);
      case 'quran':
        return const Color(0xFF059669);
      case 'tahfidz':
        return const Color(0xFF7C3AED);
      case 'jurnal':
        return const Color(0xFF64748B);
      case 'evaluasi':
        return AppTheme.softBlue;
      default:
        return AppTheme.grey400;
    }
  }

  // ── Single timeline event item ──
  Widget _buildTimelineItem({
    required WaliTimelineEvent event,
    required bool showLine,
  }) {
    final eventColor = _getEventColor(event.type);
    final lineColor = AppTheme.primaryGreen.withOpacity(0.25);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline dot + line
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: eventColor.withOpacity(0.12),
                  ),
                  child: Icon(
                    _getEventIcon(event.type),
                    size: 14,
                    color: eventColor,
                  ),
                ),
                if (showLine)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      color: lineColor,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Event content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Description
                  Text(
                    event.description,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 3),

                  // Timestamp
                  Text(
                    event.formattedTimestamp,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.grey400,
                      fontWeight: FontWeight.w400,
                    ),
                  ),

                  // Badge(s)
                  if (event.type == 'tahfidz' &&
                      event.badges != null &&
                      event.badges!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: event.badges!.map((b) {
                        final grade = b['grade'] ?? '';
                        final surah = b['surah'] ?? '';
                        final color = _getBadgeColor(grade);
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            event.badges!.length > 1
                                ? '$surah: $grade'
                                : grade,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: color,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ] else if (event.badge != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getBadgeColor(event.badge!).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        event.badge!,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _getBadgeColor(event.badge!),
                        ),
                      ),
                    ),
                  ],

                  // Detail
                  if (event.detail != null) ...[
                    const SizedBox(height: 6),
                    if (event.type == 'evaluasi' &&
                        event.evaluasiData != null) ...[
                      GestureDetector(
                        onTap: () => _openEvaluasiBottomSheet(event),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.softBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppTheme.softBlue.withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.open_in_new_rounded,
                                size: 12,
                                color: AppTheme.softBlue,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Buka Evaluasi',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.softBlue,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      Text(
                        event.detail!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: AppTheme.grey400,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],

                  // Points
                  if (event.points > 0) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppTheme.primaryGreen.withOpacity(0.15),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.star_rounded,
                            size: 12,
                            color: AppTheme.primaryGreen,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '+${event.points} poin',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getBadgeColor(String badge) {
    switch (badge.toLowerCase()) {
      case 'jamaah':
        return AppTheme.primaryGreen;
      case 'combo':
        return const Color(0xFFEA580C);
      // Letter grades
      case 'a':
        return const Color(0xFF7C3AED);
      case 'b+':
        return const Color(0xFF3B82F6);
      case 'b':
        return const Color(0xFF059669);
      case 'c':
        return const Color(0xFFF59E0B);
      case 'd':
        return const Color(0xFFEF4444);
      default:
        return AppTheme.grey400;
    }
  }
}
