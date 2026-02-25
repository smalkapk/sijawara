import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../pages/guru_diskusi_wali_page.dart';
import '../pages/guru_kelas_tahfidz_list_page.dart';
import '../pages/guru_tugas_page.dart';
import '../pages/guru_maklumat_page.dart';

class GuruDashboardSummary extends StatelessWidget {
  const GuruDashboardSummary({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          boxShadow: AppTheme.softShadow,
          border: Border.all(color: AppTheme.grey100, width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildMainFeature(
              context,
              'Tugas',
              Icons.assignment_rounded,
              AppTheme.softPurple,
              () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GuruTugasPage()),
                );
              },
            ),
             _buildMainFeature(
              context,
              'Tahfidz',
              Icons.menu_book_rounded,
              AppTheme.gold,
              () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GuruKelasTahfidzListPage()),
                );
              },
            ),
            _buildMainFeature(
              context,
              'Diskusi',
               Icons.forum_rounded,
              AppTheme.primaryGreen,
              () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GuruDiskusiWaliPage()),
                );
              },
            ),
             _buildMainFeature(
               context,
              'Maklumat',
               Icons.campaign_rounded,
              const Color(0xFFEF4444),
               () {
                 HapticFeedback.lightImpact();
                 Navigator.push(
                   context,
                   MaterialPageRoute(builder: (_) => const GuruMaklumatPage()),
                 );
               },
             ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainFeature(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
       behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

