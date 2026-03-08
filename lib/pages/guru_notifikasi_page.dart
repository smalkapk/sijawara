import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';

class GuruNotifikasiPage extends StatefulWidget {
  const GuruNotifikasiPage({super.key});

  @override
  State<GuruNotifikasiPage> createState() => _GuruNotifikasiPageState();
}

class _GuruNotifikasiPageState extends State<GuruNotifikasiPage> {
  // Keseluruhan notifikasi
  bool _masterEnabled = true;

  // Aplikasi
  bool _diskusiWaliMurid = true;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _masterEnabled = prefs.getBool('guru_notif_master') ?? true;
      _diskusiWaliMurid = prefs.getBool('guru_notif_diskusi_wali_murid') ?? true;
    });
  }

  Future<void> _savePrefs() async {
    setState(() => _isSaving = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('guru_notif_master', _masterEnabled);
    await prefs.setBool('guru_notif_diskusi_wali_murid', _diskusiWaliMurid);

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

                    // Aplikasi section
                    _buildSectionHeader(
                      icon: Icons.notifications_rounded,
                      iconGradient: AppTheme.sunsetGradient,
                      title: 'Notifikasi Aplikasi',
                      subtitle: 'Aktivitas & info dari aplikasi',
                      showIcon: false,
                    ),
                    const SizedBox(height: 10),
                    _buildCard([
                      _buildToggleItem(
                        label: 'Diskusi Wali Murid',
                        icon: Icons.forum_outlined,
                        iconColor: AppTheme.softBlue,
                        value: _diskusiWaliMurid,
                        onChanged: _masterEnabled
                            ? (v) => setState(() => _diskusiWaliMurid = v)
                            : null,
                        showIcon: false,
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
    bool showIcon = true,
  }) {
    final children = <Widget>[];
    if (showIcon) {
      children.addAll([
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: iconGradient,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: AppTheme.white),
        ),
        const SizedBox(width: 10),
      ]);
    }

    children.add(
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
    );

    return Row(children: children);
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
    bool showIcon = true,
  }) {
    final disabled = onChanged == null;
    final rowChildren = <Widget>[];

    if (showIcon) {
      rowChildren.addAll([
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: disabled
                ? AppTheme.grey100
                : iconColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon,
              size: 16, color: disabled ? AppTheme.grey200 : iconColor),
        ),
        const SizedBox(width: 12),
      ]);
    }

    rowChildren.addAll([
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
    ]);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: rowChildren),
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
