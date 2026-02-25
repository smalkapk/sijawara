import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  // Keseluruhan notifikasi
  bool _masterEnabled = true;

  // Ibadah
  bool _shalatFajr = true;
  bool _shalatDhuhur = true;
  bool _shalatAshr = true;
  bool _shalatMaghrib = true;
  bool _shalatIsya = true;

  // Aplikasi
  bool _reminderHarian = true;
  bool _pengumumanSekolah = true;
  bool _diskusiBalasan = false;
  bool _poinBaru = true;
  bool _badgeBaru = true;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _masterEnabled = prefs.getBool('notif_master') ?? true;
      _shalatFajr = prefs.getBool('notif_shalat_fajr') ?? true;
      _shalatDhuhur = prefs.getBool('notif_shalat_dhuhur') ?? true;
      _shalatAshr = prefs.getBool('notif_shalat_ashr') ?? true;
      _shalatMaghrib = prefs.getBool('notif_shalat_maghrib') ?? true;
      _shalatIsya = prefs.getBool('notif_shalat_isya') ?? true;
      _reminderHarian = prefs.getBool('notif_reminder_harian') ?? true;
      _pengumumanSekolah = prefs.getBool('notif_pengumuman') ?? true;
      _diskusiBalasan = prefs.getBool('notif_diskusi') ?? false;
      _poinBaru = prefs.getBool('notif_poin') ?? true;
      _badgeBaru = prefs.getBool('notif_badge') ?? true;
    });
  }

  Future<void> _savePrefs() async {
    setState(() => _isSaving = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_master', _masterEnabled);
    await prefs.setBool('notif_shalat_fajr', _shalatFajr);
    await prefs.setBool('notif_shalat_dhuhur', _shalatDhuhur);
    await prefs.setBool('notif_shalat_ashr', _shalatAshr);
    await prefs.setBool('notif_shalat_maghrib', _shalatMaghrib);
    await prefs.setBool('notif_shalat_isya', _shalatIsya);
    await prefs.setBool('notif_reminder_harian', _reminderHarian);
    await prefs.setBool('notif_pengumuman', _pengumumanSekolah);
    await prefs.setBool('notif_diskusi', _diskusiBalasan);
    await prefs.setBool('notif_poin', _poinBaru);
    await prefs.setBool('notif_badge', _badgeBaru);
    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppTheme.white, size: 18),
            SizedBox(width: 8),
            Text('Pengaturan notifikasi disimpan',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
        backgroundColor: AppTheme.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                child: Column(
                  children: [
                    // Master toggle card
                    _buildMasterToggle(),
                    const SizedBox(height: 20),

                    // Shalat section
                    _buildSectionHeader(
                      icon: Icons.mosque_rounded,
                      iconGradient: AppTheme.mainGradient,
                      title: 'Pengingat Shalat',
                      subtitle: 'Notifikasi waktu shalat 5 waktu',
                    ),
                    const SizedBox(height: 10),
                    _buildCard([
                      _buildToggleItem(
                        label: 'Shalat Fajr (Subuh)',
                        icon: Icons.wb_twilight_rounded,
                        iconColor: const Color(0xFF6366F1),
                        value: _shalatFajr,
                        onChanged: _masterEnabled
                            ? (v) => setState(() => _shalatFajr = v)
                            : null,
                      ),
                      _buildDivider(),
                      _buildToggleItem(
                        label: 'Shalat Dhuhur',
                        icon: Icons.wb_sunny_rounded,
                        iconColor: AppTheme.gold,
                        value: _shalatDhuhur,
                        onChanged: _masterEnabled
                            ? (v) => setState(() => _shalatDhuhur = v)
                            : null,
                      ),
                      _buildDivider(),
                      _buildToggleItem(
                        label: 'Shalat Ashr',
                        icon: Icons.wb_sunny_outlined,
                        iconColor: AppTheme.warmOrange,
                        value: _shalatAshr,
                        onChanged: _masterEnabled
                            ? (v) => setState(() => _shalatAshr = v)
                            : null,
                      ),
                      _buildDivider(),
                      _buildToggleItem(
                        label: 'Shalat Maghrib',
                        icon: Icons.nights_stay_outlined,
                        iconColor: const Color(0xFFEC4899),
                        value: _shalatMaghrib,
                        onChanged: _masterEnabled
                            ? (v) => setState(() => _shalatMaghrib = v)
                            : null,
                      ),
                      _buildDivider(),
                      _buildToggleItem(
                        label: 'Shalat Isya',
                        icon: Icons.bedtime_rounded,
                        iconColor: AppTheme.softPurple,
                        value: _shalatIsya,
                        onChanged: _masterEnabled
                            ? (v) => setState(() => _shalatIsya = v)
                            : null,
                      ),
                    ]),

                    const SizedBox(height: 20),

                    // Aplikasi section
                    _buildSectionHeader(
                      icon: Icons.notifications_rounded,
                      iconGradient: AppTheme.sunsetGradient,
                      title: 'Notifikasi Aplikasi',
                      subtitle: 'Aktivitas & info dari aplikasi',
                    ),
                    const SizedBox(height: 10),
                    _buildCard([
                      _buildToggleItem(
                        label: 'Reminder Harian Ibadah',
                        icon: Icons.wb_sunny_rounded,
                        iconColor: AppTheme.primaryGreen,
                        value: _reminderHarian,
                        onChanged: _masterEnabled
                            ? (v) => setState(() => _reminderHarian = v)
                            : null,
                      ),
                      _buildDivider(),
                      _buildToggleItem(
                        label: 'Pengumuman Sekolah',
                        icon: Icons.campaign_outlined,
                        iconColor: AppTheme.softBlue,
                        value: _pengumumanSekolah,
                        onChanged: _masterEnabled
                            ? (v) =>
                                setState(() => _pengumumanSekolah = v)
                            : null,
                      ),
                      _buildDivider(),
                      _buildToggleItem(
                        label: 'Balasan Diskusi',
                        icon: Icons.forum_outlined,
                        iconColor: AppTheme.teal,
                        value: _diskusiBalasan,
                        onChanged: _masterEnabled
                            ? (v) => setState(() => _diskusiBalasan = v)
                            : null,
                      ),
                      _buildDivider(),
                      _buildToggleItem(
                        label: 'Poin Baru Diperoleh',
                        icon: Icons.stars_rounded,
                        iconColor: AppTheme.gold,
                        value: _poinBaru,
                        onChanged: _masterEnabled
                            ? (v) => setState(() => _poinBaru = v)
                            : null,
                      ),
                      _buildDivider(),
                      _buildToggleItem(
                        label: 'Badge Baru Didapat',
                        icon: Icons.military_tech_rounded,
                        iconColor: const Color(0xFFCD7F32),
                        value: _badgeBaru,
                        onChanged: _masterEnabled
                            ? (v) => setState(() => _badgeBaru = v)
                            : null,
                      ),
                    ]),
                    const SizedBox(height: 28),
                    _buildSaveButton(),
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

  Widget _buildHeader() {
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
                    Icon(Icons.notifications_none_rounded,
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
                  'Notifikasi',
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

  Widget _buildMasterToggle() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: _masterEnabled ? AppTheme.mainGradient : null,
        color: _masterEnabled ? null : AppTheme.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow:
            _masterEnabled ? AppTheme.greenGlow : AppTheme.softShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _masterEnabled
                  ? AppTheme.white.withOpacity(0.2)
                  : AppTheme.grey100,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.notifications_active_rounded,
              size: 22,
              color:
                  _masterEnabled ? AppTheme.white : AppTheme.grey400,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aktifkan Semua Notifikasi',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color:
                        _masterEnabled ? AppTheme.white : AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _masterEnabled
                      ? 'Notifikasi aktif'
                      : 'Semua notifikasi dinonaktifkan',
                  style: TextStyle(
                    fontSize: 12,
                    color: _masterEnabled
                        ? AppTheme.white.withOpacity(0.75)
                        : AppTheme.grey400,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _masterEnabled,
            onChanged: (v) {
              HapticFeedback.lightImpact();
              setState(() => _masterEnabled = v);
            },
            activeColor: AppTheme.white,
            activeTrackColor: AppTheme.white.withOpacity(0.4),
            inactiveThumbColor: AppTheme.grey400,
            inactiveTrackColor: AppTheme.grey100,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required LinearGradient iconGradient,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: iconGradient,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: AppTheme.white),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.grey400,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(children: children),
    );
  }

  Widget _buildToggleItem({
    required String label,
    required IconData icon,
    required Color iconColor,
    required bool value,
    required void Function(bool)? onChanged,
  }) {
    final disabled = onChanged == null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: disabled
                  ? AppTheme.grey100
                  : iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon,
                size: 16,
                color: disabled ? AppTheme.grey200 : iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: disabled ? AppTheme.grey200 : AppTheme.textPrimary,
              ),
            ),
          ),
          Switch(
            value: value && !disabled,
            onChanged: onChanged != null
                ? (v) {
                    HapticFeedback.lightImpact();
                    onChanged(v);
                  }
                : null,
            activeColor: AppTheme.white,
            activeTrackColor: AppTheme.primaryGreen,
            inactiveThumbColor: AppTheme.grey200,
            inactiveTrackColor: AppTheme.grey100,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(height: 1, color: AppTheme.grey100),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSaving
            ? null
            : () {
                HapticFeedback.mediumImpact();
                _savePrefs();
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryGreen,
          foregroundColor: AppTheme.white,
          disabledBackgroundColor: AppTheme.grey200,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _isSaving
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppTheme.white),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.save_rounded, size: 18),
                  SizedBox(width: 8),
                  Text('Simpan Pengaturan',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                ],
              ),
      ),
    );
  }
}
