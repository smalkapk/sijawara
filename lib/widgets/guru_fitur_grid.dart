import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../pages/guru_alka_ai_page.dart';
import '../pages/guru_evaluasi_list_page.dart';
import '../pages/guru_ibadah_student_list_page.dart';

class GuruFiturGrid extends StatelessWidget {
  const GuruFiturGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
        color: AppTheme.grey100,
        width: 1,
      ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
            ],
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              const double spacing = 12.0;
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
                    'ALKA AI',
                    Icons.auto_awesome,
                    AppTheme.primaryGreen,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const GuruAlkaAiPage(),
                        ),
                      );
                    },
                  ),
                  buildGridItem(
                    'Ibadah',
                    Icons.mosque,
                    AppTheme.softPurple,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const GuruIbadahStudentListPage(),
                        ),
                      );
                    },
                  ),
                  buildGridItem(
                    'Evaluasi',
                    Icons.check_circle,
                    AppTheme.softBlue,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const GuruEvaluasiListPage(),
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
