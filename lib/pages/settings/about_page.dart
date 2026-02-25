import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    // App identity card
                    _buildAppCard(),
                    const SizedBox(height: 24),

                    // Info section
                    _buildSectionTitle('Informasi Aplikasi'),
                    const SizedBox(height: 10),
                    _buildInfoCard(context),

                    const SizedBox(height: 24),

                    // School info section
                    _buildSectionTitle('Tentang Sekolah'),
                    const SizedBox(height: 10),
                    _buildSchoolCard(context),

                    const SizedBox(height: 24),

                    // Tech stack section
                    _buildSectionTitle('Teknologi'),
                    const SizedBox(height: 10),
                    _buildTechCard(),

                    const SizedBox(height: 24),

                    // Support / contact
                    _buildSectionTitle('Dukungan & Kontak'),
                    const SizedBox(height: 10),
                    _buildContactCard(context),

                    const SizedBox(height: 24),
                    _buildFooter(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 24, 16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 18, color: AppTheme.textPrimary),
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.white,
              padding: const EdgeInsets.all(10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 13, color: AppTheme.textSecondary),
                    const SizedBox(width: 5),
                    Text(
                      'Pengaturan',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Tentang Aplikasi',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
      decoration: BoxDecoration(
        gradient: AppTheme.mainGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.greenGlow,
      ),
      child: Column(
        children: [
          // App icon
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                  color: AppTheme.white.withOpacity(0.3), width: 2),
            ),
            child: const Center(
              child: Icon(Icons.mosque_rounded,
                  size: 36, color: AppTheme.white),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'SiJawara',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: AppTheme.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Sistem Informasi Jaring Karakter',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTheme.white.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 16),
          // Version badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.tag_rounded,
                    size: 14, color: AppTheme.softGold),
                SizedBox(width: 4),
                Text(
                  'Versi 1.0.0',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    final items = [
      {
        'icon': Icons.info_outline_rounded,
        'iconColor': AppTheme.softBlue,
        'label': 'Nama Aplikasi',
        'value': 'SiJawara',
      },
      {
        'icon': Icons.tag_rounded,
        'iconColor': AppTheme.primaryGreen,
        'label': 'Versi',
        'value': '1.0.0',
      },
      {
        'icon': Icons.build_outlined,
        'iconColor': AppTheme.warmOrange,
        'label': 'Build',
        'value': '20260219',
      },
      {
        'icon': Icons.devices_rounded,
        'iconColor': AppTheme.teal,
        'label': 'Platform',
        'value': 'Android & iOS',
      },
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        children: List.generate(items.length, (i) {
          final item = items[i];
          return Column(
            children: [
              _buildInfoRow(
                icon: item['icon'] as IconData,
                iconColor: item['iconColor'] as Color,
                label: item['label'] as String,
                value: item['value'] as String,
              ),
              if (i < items.length - 1)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(height: 1, color: AppTheme.grey100),
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildSchoolCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: AppTheme.mainGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Icon(Icons.school_rounded,
                      size: 26, color: AppTheme.white),
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SMA Muhammadiyah',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      'Al Kautsar Program Khusus',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Bandar Lampung, Lampung',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.grey400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: AppTheme.grey100),
          const SizedBox(height: 16),
          _buildInfoRow(
            icon: Icons.language_rounded,
            iconColor: AppTheme.softBlue,
            label: 'Website',
            value: 'portal-smalka.com',
            onTap: () => _launchUrl('https://portal-smalka.com'),
          ),
        ],
      ),
    );
  }

  Widget _buildTechCard() {
    final techs = [
      {
        'icon': Icons.flutter_dash,
        'color': const Color(0xFF54C5F8),
        'name': 'Flutter',
        'desc': 'UI Framework'
      },
      {
        'icon': Icons.storage_rounded,
        'color': AppTheme.warmOrange,
        'name': 'PHP + MySQL',
        'desc': 'Backend API'
      },
      {
        'icon': Icons.cloud_rounded,
        'color': AppTheme.softBlue,
        'name': 'REST API',
        'desc': 'Komunikasi server'
      },
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        children: techs.map((tech) {
          return Expanded(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (tech['color'] as Color).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(tech['icon'] as IconData,
                      size: 22, color: tech['color'] as Color),
                ),
                const SizedBox(height: 8),
                Text(
                  tech['name'] as String,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  tech['desc'] as String,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.grey400,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildContactCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        children: [
          _buildInfoRow(
            icon: Icons.email_outlined,
            iconColor: AppTheme.softBlue,
            label: 'Email Dukungan',
            value: 'info@portal-smalka.com',
            onTap: () =>
                _launchUrl('mailto:info@portal-smalka.com'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 1, color: AppTheme.grey100),
          ),
          _buildInfoRow(
            icon: Icons.bug_report_outlined,
            iconColor: const Color(0xFFEF4444),
            label: 'Laporkan Masalah',
            value: 'Kirim laporan',
            onTap: () =>
                _launchUrl('mailto:info@portal-smalka.com?subject=Bug Report SiJawara'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 1, color: AppTheme.grey100),
          ),
          _buildInfoRow(
            icon: Icons.star_outline_rounded,
            iconColor: AppTheme.gold,
            label: 'Beri Ulasan',
            value: 'Play Store',
            onTap: () {
              HapticFeedback.lightImpact();
              // TODO: replace with actual Play Store link
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap != null
          ? () {
              HapticFeedback.lightImpact();
              onTap();
            }
          : null,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 16, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.grey400,
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: onTap != null
                          ? AppTheme.primaryGreen
                          : AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppTheme.grey400),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Text(
          'Made with ❤️ for SMA Muhammadiyah Al Kautsar PK',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.grey400,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          '© 2026 SiJawara. All rights reserved.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            color: AppTheme.grey200,
          ),
        ),
      ],
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
