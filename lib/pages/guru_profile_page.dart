import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';
import '../services/auth_service.dart';
import 'login_page.dart';
import 'guru_bantuan_page.dart';
import 'guru_profil_anda_page.dart';
import 'guru_notifikasi_page.dart';
import 'guru_keamanan_page.dart';
import 'guru_tentang_kami_page.dart';

class GuruProfilePage extends StatefulWidget {
  const GuruProfilePage({super.key});

  @override
  State<GuruProfilePage> createState() => _GuruProfilePageState();
}

class _GuruProfilePageState extends State<GuruProfilePage> {
  String _userName = '';
  String _userRole = '';
  String _className = 'Kelas X'; // TBD: Fetch from actual data if available

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('user_name') ?? 'Guru';
      _userRole = prefs.getString('user_role') ?? '';
    });
  }

  String get _roleLabel {
    if (_userRole == 'guru_tahfidz') return 'Guru Tahfidz';
    if (_userRole == 'guru_kelas') return 'Guru Kelas';
    return 'Guru';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildHeader(context),
              const SizedBox(height: 16),

              // Profile Photo Centered
              _buildCenteredProfileInfo(),

              const SizedBox(height: 32),

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
      width: double.infinity,
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
            'Profil Guru',
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

  Widget _buildCenteredProfileInfo() {
    return Column(
      children: [
        // Avatar
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppTheme.primaryGreen.withOpacity(0.3),
              width: 3,
            ),
            color: AppTheme.primaryGreen.withOpacity(0.1),
          ),
          child: const Center(
            child: Icon(
              Icons.person_rounded,
              size: 48,
              color: AppTheme.primaryGreen,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Name
        Text(
          _userName,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 8),

        // Role / Class
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$_roleLabel • $_className',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryGreen,
            ),
          ),
        ),
      ],
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
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const GuruProfilAndaPage(),
                  ),
                );
              },
            ),
            _buildDivider(),
            _buildSettingsTile(
              icon: Icons.notifications_rounded,
              title: 'Notifikasi',
              subtitle: 'Atur pemberitahuan',
              color: AppTheme.warmOrange,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const GuruNotifikasiPage(),
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
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const GuruKeamananPage(),
                  ),
                );
              },
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
                    builder: (context) => const GuruBantuanPage(),
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
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const GuruTentangKamiPage(),
                  ),
                );
              },
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
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
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
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
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
      await AuthService.logout();

      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    }
  }
}
