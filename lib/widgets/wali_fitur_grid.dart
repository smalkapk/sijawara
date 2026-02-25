import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../pages/wali_tugas_siswa_page.dart';
import '../pages/wali_maklumat_page.dart';
import '../pages/wali_diskusi_guru_page.dart';
import '../pages/wali_aduan_aplikasi_page.dart';
import '../pages/wali_bantuan_page.dart';
import '../pages/wali_alka_ai_page.dart';
import '../pages/wali_sp_siswa_page.dart';

class WaliFiturGrid extends StatelessWidget {
  const WaliFiturGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Search & Atur Fitur
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.bgColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.search_rounded,
                        size: 18,
                        color: AppTheme.grey400,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Cari fitur...',
                            hintStyle: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: AppTheme.grey400),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 11,
                            ),
                          ),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  gradient: AppTheme.mainGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: AppTheme.greenGlow,
                ),
                child: Center(
                  child: Text(
                    'Atur Fitur',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppTheme.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Grid 4x2
          LayoutBuilder(
            builder: (context, constraints) {
              const double spacing = 12.0;
              // Calculate exactly 1/4th of the width for 4 columns
              final double itemWidth =
                  (constraints.maxWidth - (spacing * 3)) / 4;

              Widget buildGridItem(
                String title,
                IconData icon,
                Color color, {
                VoidCallback? onTap,
              }) {
                return SizedBox(
                  width: itemWidth,
                  child: _buildFiturItem(context, title, icon, color, onTap),
                );
              }

              return Wrap(
                alignment: WrapAlignment.center,
                spacing: spacing,
                runSpacing: 16.0,
                children: [
                  buildGridItem(
                    'Tugas Siswa',
                    Icons.forum_rounded,
                    AppTheme.softBlue,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const WaliTugasSiswaPage(),
                        ),
                      );
                    },
                  ),
                  buildGridItem(
                    'Maklumat',
                    Icons.notifications_active_rounded,
                    const Color(0xFFEF4444),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const WaliMaklumatPage(),
                        ),
                      );
                    },
                  ),
                  buildGridItem(
                    'Diskusi Guru',
                    Icons.mail_rounded,
                    AppTheme.primaryGreen,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const WaliDiskusiGuruPage(),
                        ),
                      );
                    },
                  ),
                  buildGridItem(
                    'Aduan Aplikasi',
                    Icons.bug_report_rounded,
                    AppTheme.softPurple,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const WaliAduanAplikasiPage(),
                        ),
                      );
                    },
                  ),
                  buildGridItem(
                    'Bantuan',
                    Icons.help_outline_rounded,
                    AppTheme.teal,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const WaliBantuanPage(),
                        ),
                      );
                    },
                  ),
                  buildGridItem(
                    'ALKA AI',
                    Icons.auto_awesome,
                    AppTheme.teal,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const WaliAlkaAiPage(),
                        ),
                      );
                    },
                  ),
                  buildGridItem(
                    'SP Siswa',
                    Icons.warning_amber_rounded,
                    AppTheme.gold,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const WaliSpSiswaPage(),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFiturItem(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback? onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 10,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
