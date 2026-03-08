import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/wali_service.dart';
import 'wali_monthly_calendar.dart';

/// Status shalat 5 waktu hari ini — tampilan simpel untuk orang tua.
class WaliIbadahStatus extends StatelessWidget {
  final List<WaliPrayerItem> prayers;
  final WaliDailyExtras? extras;
  final WaliTodaySummary? summary;
  final String studentName;
  final int studentId;

  const WaliIbadahStatus({
    super.key,
    required this.prayers,
    this.extras,
    this.summary,
    this.studentName = '',
    required this.studentId,
  });

  // Jam adzan untuk tampilan waktu shalat
  static const Map<String, String> _defaultTimes = {
    'Subuh': '04:30',
    'Dzuhur': '11:45',
    'Ashar': '15:05',
    'Maghrib': '17:50',
    'Isya': '19:05',
  };

  // Batas akhir waktu shalat daerah Sukoharjo (WIB)
  static const Map<String, String> _prayerDeadlines = {
    'Subuh': '05:30',
    'Dzuhur': '14:30',
    'Ashar': '17:30',
    'Maghrib': '18:45',
    'Isya': '23:59',
  };

  @override
  Widget build(BuildContext context) {
    final doneCount = prayers.where((p) => p.isDone).length;
    final hasWakeUp = extras != null && extras!.wakeUpTime != null;
    final hasDeeds = extras != null && extras!.deeds.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 5 waktu shalat + ringkasan extras dalam satu card
          GestureDetector(
            onTap: () => _showPrayerReportSheet(context),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppTheme.grey100, width: 1),
              ),
              child: Column(
                children: [
                  // Shalat circles
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: _buildShalatCircles(),
                  ),

                  // Jam Bangun & Kebaikan summary
                  if (hasWakeUp || hasDeeds) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Divider(
                        height: 1,
                        color: AppTheme.grey100,
                      ),
                    ),
                    Row(
                      children: [
                        // Jam Bangun
                        if (hasWakeUp)
                          Expanded(
                            child: _buildExtraSummaryItem(
                              icon: Icons.alarm_rounded,
                              iconColor: AppTheme.gold,
                              label: 'Bangun',
                              value: '${extras!.wakeUpTime} WIB',
                              points: extras!.wakeUpPoints,
                              pointsColor: AppTheme.gold,
                            ),
                          ),

                        if (hasWakeUp && hasDeeds)
                          Container(
                            width: 1,
                            height: 36,
                            color: AppTheme.grey100,
                          ),

                        // Kebaikan
                        if (hasDeeds)
                          Expanded(
                            child: _buildExtraSummaryItem(
                              icon: Icons.volunteer_activism_rounded,
                              iconColor: AppTheme.primaryGreen,
                              label: 'Kebaikan',
                              value: '${extras!.deeds.length} tercatat',
                              points: extras!.deedsPoints,
                              pointsColor: AppTheme.primaryGreen,
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
      ),
    );
  }

  Widget _buildExtraSummaryItem({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required int points,
    required Color pointsColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconColor.withOpacity(0.12),
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.grey400,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: pointsColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '+$points',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: pointsColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildShalatCircles() {
    final prayerNames = ['Subuh', 'Dzuhur', 'Ashar', 'Maghrib', 'Isya'];
    final now = TimeOfDay.now();
    final nowMinutes = now.hour * 60 + now.minute;

    return prayerNames.map((name) {
      // Cari data prayer dari API
      var prayer = prayers.firstWhere(
        (p) => p.name == name,
        orElse: () => WaliPrayerItem(name: name, status: 'upcoming', points: 0),
      );

      // Client-side fallback: jika status masih 'upcoming' tapi sudah lewat
      // deadline waktu shalat, override ke 'missed'
      if (prayer.isUpcoming) {
        final deadline = _prayerDeadlines[name];
        if (deadline != null) {
          final parts = deadline.split(':');
          final deadlineMinutes = int.parse(parts[0]) * 60 + int.parse(parts[1]);
          if (nowMinutes > deadlineMinutes) {
            prayer = WaliPrayerItem(name: name, status: 'missed', points: 0);
          }
        }
      }

      return _buildShalatCircle(name, prayer);
    }).toList();
  }

  Widget _buildShalatCircle(String name, WaliPrayerItem prayer) {
    Color bgColor;
    Color iconColor;
    IconData icon;
    String subtitle;

    if (prayer.isJamaah) {
      bgColor = AppTheme.primaryGreen.withOpacity(0.12);
      iconColor = AppTheme.primaryGreen;
      icon = Icons.check_circle_rounded;
      subtitle = "Jama'ah";
    } else if (prayer.isDone) {
      bgColor = AppTheme.primaryGreen.withOpacity(0.10);
      iconColor = AppTheme.primaryGreen;
      icon = Icons.check_circle_outline_rounded;
      subtitle = 'Sudah';
    } else if (prayer.isMissed) {
      bgColor = const Color(0xFFEF4444).withOpacity(0.12);
      iconColor = const Color(0xFFEF4444);
      icon = Icons.cancel_outlined;
      subtitle = 'Belum';
    } else {
      bgColor = AppTheme.primaryGreen.withOpacity(0.06);
      iconColor = AppTheme.primaryGreen.withOpacity(0.5);
      icon = Icons.schedule_rounded;
      subtitle = _defaultTimes[name] ?? '';
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Circle
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(shape: BoxShape.circle, color: bgColor),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(height: 8),
        // Name
        Text(
          name,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        // Status / time
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: prayer.isMissed
                ? const Color(0xFFEF4444)
                : AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  void _showPrayerReportSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _WaliPrayerReportSheet(
        prayers: prayers,
        extras: extras,
        studentName: studentName,
        studentId: studentId,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// ───── Bottom Sheet: Laporan Shalat (Read-Only) ──────
// ═══════════════════════════════════════════════════════

class _WaliPrayerReportSheet extends StatelessWidget {
  final List<WaliPrayerItem> prayers;
  final WaliDailyExtras? extras;
  final String studentName;
  final int studentId;

  const _WaliPrayerReportSheet({
    required this.prayers,
    this.extras,
    this.studentName = '',
    required this.studentId,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // Handle bar (non-scrollable)
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

              // Header (non-scrollable)
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Laporan Shalat',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Data terbaru hari ini',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
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
                    // ── Shalat List ──
                    ...prayers.map(
                      (item) => _buildReportItem(item),
                    ),

                    const SizedBox(height: 20),

                    // ── Seksi: Berbuat Baik ──
                    if (extras != null && extras!.deeds.isNotEmpty) ...[
                      _buildSectionHeader(
                        icon: Icons.volunteer_activism_rounded,
                        iconColor: AppTheme.primaryGreen,
                        title: 'Perbuatan Baik Hari Ini',
                        subtitle: '${extras!.deeds.length} kebaikan tercatat',
                      ),
                      const SizedBox(height: 12),
                      ...extras!.deeds.map(
                        (deed) => _buildDeedItem(
                          icon: _getDeedIcon(deed),
                          label: deed,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // ── Seksi: Bangun Pagi ──
                    if (extras != null && extras!.wakeUpTime != null) ...[
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
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                    '${extras!.wakeUpTime} WIB',
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
                                '+${extras!.wakeUpPoints} poin',
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
                      const SizedBox(height: 28),
                    ],

                    // ── Info: Belum ada data ──
                    if (extras == null && prayers.every((p) => p.isUpcoming))
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppTheme.grey100.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.info_outline_rounded,
                                color: AppTheme.grey400, size: 32),
                            SizedBox(height: 8),
                            Text(
                              'Belum ada data ibadah hari ini',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 20),

                    // ── Tombol Lihat Perbulan ──
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => WaliMonthlyCalendar(
                                studentName: studentName,
                                studentId: studentId,
                              ),
                            ),
                          );
                        },
                        label: const Text('Lihat Perbulan'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryGreen,
                          side: const BorderSide(
                            color: AppTheme.primaryGreen,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusMd,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Section Header ──
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

  // ── Deed Item ──
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

  // ── Helper: icon berdasarkan nama kebaikan ──
  IconData _getDeedIcon(String deed) {
    final lower = deed.toLowerCase();
    if (lower.contains('tahajjud')) return Icons.nightlight_rounded;
    if (lower.contains('tadarus') || lower.contains('quran')) return Icons.menu_book_rounded;
    if (lower.contains('dzikir')) return Icons.self_improvement_rounded;
    if (lower.contains('dhuha')) return Icons.wb_sunny_rounded;
    if (lower.contains('puasa')) return Icons.favorite_rounded;
    if (lower.contains('shadaqah') || lower.contains('sedekah')) return Icons.volunteer_activism_rounded;
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

    // Waktu default
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
          // Icon
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
          // Name & Time
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
                  style: const TextStyle(fontSize: 13, color: AppTheme.grey400),
                ),
              ],
            ),
          ),
          // Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
