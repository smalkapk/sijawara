import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';
import '../services/wali_service.dart';
import 'login_page.dart';
import 'wali_account_center_page.dart';
import 'wali_bantuan_page.dart';
import 'wali_profil_anda_page.dart';

class WaliProfilePage extends StatefulWidget {
  final WaliDashboardData? dashboardData;

  const WaliProfilePage({super.key, this.dashboardData});

  @override
  State<WaliProfilePage> createState() => _WaliProfilePageState();
}

class _WaliProfilePageState extends State<WaliProfilePage> {
  // ── Data State ──
  WaliDashboardData? _currentDashboardData;

  @override
  void initState() {
    super.initState();
    _currentDashboardData = widget.dashboardData;
  }

  Future<void> _refreshProfileData() async {
    try {
      final updatedProfile = await WaliService.getWaliProfile();
      if (mounted) {
        setState(() {
          if (_currentDashboardData != null) {
            _currentDashboardData = _currentDashboardData!.copyWith(
              parent: updatedProfile,
            );
          }
        });
      }
    } catch (e) {
      // Silently fail or log if needed, keep existing data
      debugPrint('Failed to refresh profile: $e');
    }
  }

  String get _parentName =>
      _currentDashboardData?.parent.name ?? '-';
  String get _parentPhone =>
      _currentDashboardData?.parent.phone ?? '-';
  String get _parentEmail =>
      _currentDashboardData?.parent.email ?? '-';
  String get _studentName =>
      _currentDashboardData?.selectedChild?.studentName ?? '-';
  String get _studentClass =>
      _currentDashboardData?.selectedChild?.className ?? '-';
  String get _studentNis =>
      _currentDashboardData?.selectedChild?.nis ?? '-';
  String get _relation {
    final rel = _currentDashboardData?.selectedChild?.relationship ?? 'wali';
    switch (rel) {
      case 'ayah':
        return 'Ayah';
      case 'ibu':
        return 'Ibu';
      case 'wali':
        return 'Wali';
      default:
        return 'Wali';
    }
  }

  String get _academicYear =>
      _currentDashboardData?.selectedChild?.academicYear ?? '-';

  String? get _avatarUrl =>
      _currentDashboardData?.parent.avatarUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 8),

              // Profile card
              _buildProfileCard(),

              const SizedBox(height: 16),

              // Student info
              _buildStudentInfo(),

              const SizedBox(height: 16),

              // Settings
              _buildSettingsSection(context),

              const SizedBox(height: 16),

              // Logout
              _buildLogoutButton(context),

              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_rounded,
                  size: 14, color: AppTheme.softPurple),
              const SizedBox(width: 6),
              Text(
                'Akun Saya',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Profil Orang Tua',
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

  Widget _buildProfileCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.mainGradient,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          boxShadow: AppTheme.greenGlow,
        ),
        child: Stack(
          children: [
            Positioned(
              top: -30,
              right: -20,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.06),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 2,
                      ),
                      color: Colors.white.withOpacity(0.15),
                      image: _avatarUrl != null && _avatarUrl!.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(
                                _avatarUrl!.startsWith('http')
                                    ? _avatarUrl!
                                    : 'https://portal-smalka.com/$_avatarUrl',
                              ),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: _avatarUrl == null || _avatarUrl!.isEmpty
                        ? const Center(
                            child: Icon(
                              Icons.family_restroom_rounded,
                              size: 28,
                              color: Colors.white,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _parentName,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Orang Tua / Wali',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _parentEmail,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentInfo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          boxShadow: AppTheme.softShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.school_rounded,
                    size: 16, color: AppTheme.primaryGreen),
                const SizedBox(width: 8),
                const Text(
                  'Data Anak',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildInfoRow('Nama Siswa', _studentName),
            _buildInfoRow('NIS', _studentNis),
            _buildInfoRow('Kelas', _studentClass),
            _buildInfoRow('Tahun Ajaran', _academicYear),
            _buildInfoRow('Hubungan', _relation),
            _buildInfoRow('No. HP Wali', _parentPhone),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Text(
            ':',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          boxShadow: AppTheme.softShadow,
        ),
        child: Column(
          children: [
            _buildSettingsTile(
              icon: Icons.person_outline_rounded,
              title: 'Profil Anda',
              subtitle: 'Informasi data diri',
              color: AppTheme.primaryGreen,
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WaliProfilAndaPage(
                      dashboardData: widget.dashboardData,
                    ),
                  ),
                );
                // Refresh profile data when returning
                _refreshProfileData();
              },
            ),
            _buildDivider(),
            _buildSettingsTile(
              icon: Icons.notifications_rounded,
              title: 'Notifikasi',
              subtitle: 'Atur pemberitahuan',
              color: AppTheme.warmOrange,
              onTap: () {},
            ),
            _buildDivider(),
            _buildSettingsTile(
              icon: Icons.manage_accounts_rounded,
              title: 'Pusat Akun',
              subtitle: 'Kelola akun siswa tertaut',
              color: AppTheme.softPurple,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const WaliAccountCenterPage(),
                  ),
                );
              },
            ),
            _buildDivider(),
            _buildSettingsTile(
              icon: Icons.lock_rounded,
              title: 'Keamanan',
              subtitle: 'Ubah kata sandi',
              color: AppTheme.softBlue,
              onTap: () {},
            ),
            _buildDivider(),
            _buildSettingsTile(
              icon: Icons.help_rounded,
              title: 'Bantuan',
              subtitle: 'Pusat bantuan & FAQ',
              color: AppTheme.teal,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const WaliBantuanPage(),
                  ),
                );
              },
            ),
            _buildDivider(),
            _buildSettingsTile(
              icon: Icons.info_outline_rounded,
              title: 'Tentang Kami',
              subtitle: 'Informasi aplikasi Sijawara',
              color: AppTheme.warmOrange,
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppTheme.grey400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(height: 1, color: AppTheme.grey100),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => _handleLogout(context),
          icon: const Icon(Icons.logout_rounded, size: 18),
          label: const Text('Keluar'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red.shade600,
            side: BorderSide(color: Colors.red.shade200),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        title: const Text('Keluar'),
        content: const Text('Apakah Anda yakin ingin keluar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_logged_in', false);
      await prefs.remove('user_role');

      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    }
  }
}
