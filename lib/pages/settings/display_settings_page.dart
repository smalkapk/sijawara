import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme.dart';

class DisplaySettingsPage extends StatefulWidget {
  const DisplaySettingsPage({super.key});

  @override
  State<DisplaySettingsPage> createState() => _DisplaySettingsPageState();
}

class _DisplaySettingsPageState extends State<DisplaySettingsPage> {
  // Tema
  String _themeMode = 'system'; // 'light', 'dark', 'system'

  // Huruf tebal
  bool _boldText = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _themeMode = prefs.getString('display_theme') ?? 'system';
      _boldText  = prefs.getBool('display_bold_text') ?? false;
    });
  }

  /// Simpan langsung — dipanggil setiap kali ada perubahan.
  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('display_theme', _themeMode);
    await prefs.setBool('display_bold_text', _boldText);
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
                    // Tema
                    _buildSectionHeader(
                      icon: Icons.palette_outlined,
                      iconGradient: const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      title: 'Tema Aplikasi',
                      subtitle: 'Pilih tampilan terang, gelap, atau otomatis',
                    ),
                    const SizedBox(height: 12),
                    _buildThemeSelector(),

                    const SizedBox(height: 24),

                    // ── Huruf Tebal ──
                    _buildSectionHeader(
                      icon: Icons.format_bold_rounded,
                      iconGradient: AppTheme.sunsetGradient,
                      title: 'Huruf Tebal',
                      subtitle: 'Terapkan teks tebal di seluruh aplikasi',
                    ),
                    const SizedBox(height: 12),
                    _buildBoldTextSelector(),
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
                    Icon(Icons.palette_outlined,
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
                  'Tampilan',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                ),
              ],
            ),
          ),
          // Badge auto-save
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sync_rounded, size: 12, color: AppTheme.primaryGreen),
                SizedBox(width: 4),
                Text(
                  'Auto simpan',
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
              style: const TextStyle(fontSize: 11, color: AppTheme.grey400),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildThemeSelector() {
    const options = [
      {'value': 'light', 'label': 'Terang', 'icon': Icons.wb_sunny_rounded},
      {'value': 'dark', 'label': 'Gelap', 'icon': Icons.bedtime_rounded},
      {
        'value': 'system',
        'label': 'Otomatis',
        'icon': Icons.brightness_auto_rounded
      },
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        children: options.map((opt) {
          final isSelected = _themeMode == opt['value'];
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _themeMode = opt['value'] as String);
                _savePrefs();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.all(6),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: isSelected ? AppTheme.mainGradient : null,
                  color: isSelected ? null : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: isSelected ? AppTheme.greenGlow : null,
                ),
                child: Column(
                  children: [
                    Icon(
                      opt['icon'] as IconData,
                      size: 22,
                      color: isSelected
                          ? AppTheme.white
                          : AppTheme.grey400,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      opt['label'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? AppTheme.white
                            : AppTheme.grey400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBoldTextSelector() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        children: [
          // Preview
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            decoration: BoxDecoration(
              color: AppTheme.bgColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Text(
                  'Contoh Teks Judul',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: _boldText ? FontWeight.w900 : FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ini adalah contoh teks isi / deskripsi',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: _boldText ? FontWeight.w700 : FontWeight.w400,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          // Toggle row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.warmOrange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.format_bold_rounded,
                    size: 20, color: AppTheme.warmOrange),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Aktifkan Huruf Tebal',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      _boldText
                          ? 'Teks tampil lebih tebal & jelas'
                          : 'Teks menggunakan ketebalan standar',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.grey400,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _boldText,
                onChanged: (v) {
                  HapticFeedback.lightImpact();
                  setState(() => _boldText = v);
                  _savePrefs();
                },
                activeColor: AppTheme.white,
                activeTrackColor: AppTheme.primaryGreen,
                inactiveThumbColor: AppTheme.grey200,
                inactiveTrackColor: AppTheme.grey100,
              ),
            ],
          ),
        ],
      ),
    );
  }

}
