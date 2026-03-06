import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../services/maklumat_service.dart';

class GuruMaklumatFormPage extends StatefulWidget {
  const GuruMaklumatFormPage({super.key});

  @override
  State<GuruMaklumatFormPage> createState() => _GuruMaklumatFormPageState();
}

class _GuruMaklumatFormPageState extends State<GuruMaklumatFormPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final _judulController = TextEditingController();
  final _deskripsiController = TextEditingController();
  final Set<TextEditingController> _showHelperFor = {};
  String _selectedPriority = 'Sedang'; // Default
  String _selectedTarget = 'keduanya'; // Default kirim kepada
  String _selectedIcon = 'campaign'; // Default icon
  bool _hasImage = false;
  bool _hasPdf = false;
  bool _isSaving = false;

  final List<String> _priorities = ['Tinggi', 'Sedang', 'Rendah'];
  final List<Map<String, String>> _targets = [
    {'value': 'siswa', 'label': 'Siswa'},
    {'value': 'orang_tua', 'label': 'Orang Tua / Wali'},
    {'value': 'keduanya', 'label': 'Keduanya'},
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _fadeController.forward();
    _judulController.addListener(() {
      if (_judulController.text.trim().isNotEmpty && _showHelperFor.remove(_judulController)) {
        if (mounted) setState(() {});
      }
    });
    _deskripsiController.addListener(() {
      if (_deskripsiController.text.trim().isNotEmpty && _showHelperFor.remove(_deskripsiController)) {
        if (mounted) setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _judulController.dispose();
    _deskripsiController.dispose();
    super.dispose();
  }

  void _triggerHelper(TextEditingController controller) {
    if (_showHelperFor.contains(controller)) return;
    setState(() => _showHelperFor.add(controller));
    Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _showHelperFor.remove(controller));
    });
  }

  void _kirimForm() async {
    HapticFeedback.mediumImpact();
    if (_judulController.text.isEmpty || _deskripsiController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Judul dan Deskripsi wajib diisi'),
          backgroundColor: Colors.red.shade400,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryGreen),
      ),
    );

    try {
      await MaklumatService.createMaklumat(
        judul: _judulController.text.trim(),
        deskripsi: _deskripsiController.text.trim(),
        prioritas: _selectedPriority,
        targetAudience: _selectedTarget,
        icon: _selectedIcon,
      );

      if (mounted) {
        setState(() => _isSaving = false);
        Navigator.pop(context); // Close loading
        Navigator.pop(context, true); // Go back with result = true
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Maklumat berhasil dikirim'),
            backgroundColor: AppTheme.primaryGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengirim: $e'),
            backgroundColor: Colors.red.shade400,
          ),
        );
      }
    }
  }

  void _showEnhanceSheet(String content) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.only(top: 8),
        decoration: const BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.grey200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Icon(Icons.auto_awesome_rounded, size: 20, color: AppTheme.primaryGreen),
                        SizedBox(height: 8),
                        Text(
                          'Apa yang ingin Anda sempurnakan?',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Card with content preview
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.grey100, width: 1),
                      ),
                      child: Text(
                        content.isEmpty ? '-' : content,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Options
                    Column(
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.grey100, width: 1),
                            ),
                            child: const Icon(Icons.auto_fix_high, size: 18, color: AppTheme.primaryGreen),
                          ),
                          title: const Text('Sempurnakan'),
                          onTap: () => Navigator.pop(context),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.grey100, width: 1),
                            ),
                            child: const Icon(Icons.open_in_full, size: 18, color: AppTheme.primaryGreen),
                          ),
                          title: const Text('Perpanjang'),
                          onTap: () => Navigator.pop(context),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.grey100, width: 1),
                            ),
                            child: const Icon(Icons.compress, size: 18, color: AppTheme.primaryGreen),
                          ),
                          title: const Text('Perpendek'),
                          onTap: () => Navigator.pop(context),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.grey100, width: 1),
                            ),
                            child: const Icon(Icons.language, size: 18, color: AppTheme.primaryGreen),
                          ),
                          title: const Text('Ubah bahasa inggris'),
                          onTap: () => Navigator.pop(context),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.grey100, width: 1),
                            ),
                            child: const Icon(Icons.translate, size: 18, color: AppTheme.primaryGreen),
                          ),
                          title: const Text('Ubah Bahasa Indonesia'),
                          onTap: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInputField('Judul', _judulController, Icons.title_rounded),
                      const SizedBox(height: 16),
                      _buildInputField('Deskripsi', _deskripsiController, Icons.subject_rounded, maxLines: 5),
                      const SizedBox(height: 16),
                      _buildPriorityPicker(),
                      const SizedBox(height: 16),
                      _buildTargetAudiencePicker(),
                      const SizedBox(height: 16),
                      _buildIconPicker(),
                      const SizedBox(height: 16),
                      _buildAttachmentField(
                        title: 'Gambar Sampul',
                        icon: Icons.image_rounded,
                        isAttached: _hasImage,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() => _hasImage = !_hasImage);
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildAttachmentField(
                        title: 'Surat Digital (PDF)',
                        icon: Icons.picture_as_pdf_rounded,
                        isAttached: _hasPdf,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() => _hasPdf = !_hasPdf);
                        },
                      ),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomActions(context),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: AppTheme.mainGradient,
              ),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  color: AppTheme.primaryGreen,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.campaign_rounded,
                      size: 14,
                      color: Color(0xFFEF4444),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Form Maklumat',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Buat Maklumat',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 22,
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

  Widget _buildInputField(String label, TextEditingController controller, IconData icon, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
           children: [
             Icon(icon, size: 16, color: AppTheme.primaryGreen),
             const SizedBox(width: 8),
             Expanded(
               child: Text(
                 label,
                 style: const TextStyle(
                   fontSize: 14,
                   fontWeight: FontWeight.w700,
                   color: AppTheme.textPrimary,
                 ),
               ),
             ),
             const SizedBox(width: 8),
             AnimatedBuilder(
               animation: controller,
               builder: (context, _) {
                 final hasText = controller.text.trim().isNotEmpty;
                 return GestureDetector(
                   onTap: hasText ? () => _showEnhanceSheet(controller.text) : () => _triggerHelper(controller),
                   child: Icon(
                     Icons.auto_awesome_rounded,
                     size: 16,
                     color: hasText ? AppTheme.primaryGreen : AppTheme.grey400,
                   ),
                 );
               },
             ),
           ]
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.grey100, width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            crossAxisAlignment: maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  maxLines: maxLines,
                  minLines: maxLines > 1 ? 3 : 1,
                  decoration: InputDecoration(
                    hintText: 'Tulis $label...',
                    hintStyle: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.grey400,
                      fontWeight: FontWeight.w500,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: maxLines > 1 ? 12 : 16),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Validation hint shown only when user tapped spark with empty input
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: _showHelperFor.contains(controller)
              ? Text(
                  'Ketik terlebih dahulu',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red.shade400,
                    fontWeight: FontWeight.w600,
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildPriorityPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
           children: [
             const Icon(Icons.flag_rounded, size: 16, color: AppTheme.primaryGreen),
             const SizedBox(width: 8),
             const Text(
              'Prioritas',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
             ),
             const SizedBox(width: 4),
             GestureDetector(
               onTap: _showPriorityInfoSheet,
               child: const Icon(
                 Icons.info_outline_rounded,
                 size: 16,
                 color: AppTheme.grey400,
               ),
             ),
           ]
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.grey100, width: 1),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedPriority,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.grey400),
              items: _priorities.map((String priority) {
                return DropdownMenuItem<String>(
                  value: priority,
                  child: Text(
                    priority,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedPriority = newValue;
                  });
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTargetAudiencePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
           children: [
             const Icon(Icons.people_rounded, size: 16, color: AppTheme.primaryGreen),
             const SizedBox(width: 8),
             const Text(
              'Kirim Kepada',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
             ),
           ]
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _targets.map((target) {
            final isSelected = _selectedTarget == target['value'];
            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _selectedTarget = target['value']!);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryGreen.withOpacity(0.08)
                      : AppTheme.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? AppTheme.primaryGreen : AppTheme.grey100,
                    width: isSelected ? 1.5 : 1,
                  ),
                  // shadows removed; border indicates selection
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSelected
                          ? Icons.check_circle_rounded
                          : _getTargetIcon(target['value']!),
                      size: 18,
                      color: isSelected
                          ? AppTheme.primaryGreen
                          : AppTheme.grey400,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      target['label']!,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? AppTheme.primaryGreen
                            : AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  IconData _getTargetIcon(String target) {
    switch (target) {
      case 'siswa':
        return Icons.school_rounded;
      case 'orang_tua':
        return Icons.family_restroom_rounded;
      case 'keduanya':
        return Icons.groups_rounded;
      default:
        return Icons.people_rounded;
    }
  }

  Widget _buildIconPicker() {
    final entries = maklumatIconMap.entries.toList();
    final selectedEntry = maklumatIconMap[_selectedIcon];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.emoji_emotions_rounded, size: 16, color: AppTheme.primaryGreen),
            const SizedBox(width: 8),
            const Text(
              'Icon Maklumat',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Preview selected icon
        if (selectedEntry != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: selectedEntry.$2.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selectedEntry.$2.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.grey100, width: 1),
                  ),
                  child: Icon(selectedEntry.$1, color: selectedEntry.$2, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Icon terpilih',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.grey400,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _iconLabel(_selectedIcon),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: selectedEntry.$2,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'Ganti',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selectedEntry.$2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Icon grid
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.grey100, width: 1),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: entries.map((entry) {
              final key = entry.key;
              final iconData = entry.value.$1;
              final color = entry.value.$2;
              final isSelected = _selectedIcon == key;

              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _selectedIcon = key);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color.withOpacity(0.12)
                        : AppTheme.bgColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? color : Colors.transparent,
                      width: isSelected ? 2 : 0,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      iconData,
                      size: 24,
                      color: isSelected ? color : AppTheme.grey400,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  String _iconLabel(String key) {
    const labels = {
      'campaign': 'Pengumuman',
      'school': 'Akademik',
      'event': 'Acara',
      'info': 'Informasi',
      'warning': 'Peringatan',
      'celebration': 'Perayaan',
      'menu_book': 'Tugas / Buku',
      'emoji_events': 'Kejuaraan',
      'mosque': 'Keagamaan',
      'groups': 'Komunitas',
      'health': 'Kesehatan',
      'payments': 'Pembayaran',
      'directions_bus': 'Transportasi',
      'restaurant': 'Kantin',
      'schedule': 'Jadwal',
      'verified': 'Resmi',
    };
    return labels[key] ?? key;
  }

  Widget _buildAttachmentField({
    required String title,
    required IconData icon,
    required bool isAttached,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
           children: [
             Icon(icon, size: 16, color: AppTheme.primaryGreen),
             const SizedBox(width: 8),
             Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
             ),
           ]
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: isAttached ? AppTheme.primaryGreen.withOpacity(0.05) : AppTheme.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isAttached ? AppTheme.primaryGreen : AppTheme.grey100,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isAttached ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                  color: isAttached ? AppTheme.primaryGreen : AppTheme.grey400,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  isAttached ? 'File berhasil ditambahkan' : 'Ketuk untuk mengunggah',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isAttached ? AppTheme.primaryGreen : AppTheme.primaryGreen,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.white,
      ),
      child: SafeArea(
        child: GestureDetector(
          onTap: _isSaving ? null : _kirimForm,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: _isSaving ? null : AppTheme.mainGradient,
              color: _isSaving ? AppTheme.grey200 : null,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              boxShadow: _isSaving ? [] : AppTheme.greenGlow,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                 if (_isSaving)
                   const SizedBox(
                     width: 20,
                     height: 20,
                     child: CircularProgressIndicator(
                       strokeWidth: 2.5,
                       color: Colors.white,
                     ),
                   )
                 else
                   const Icon(
                     Icons.send_rounded,
                     color: Colors.white,
                     size: 20,
                   ),
                const SizedBox(width: 8),
                Text(
                  _isSaving ? 'Mengirim...' : 'Kirim Maklumat',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPriorityInfoSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.only(top: 8),
        decoration: const BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: AppTheme.grey200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Prioritaskan Maklumat',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Pilihan prioritas membantu kami dalam memilah dan mendistribusikan pengumuman Anda dengan tepat. Berikut pembagiannya:',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),

                      _buildPriorityInfoCard(
                        title: 'Tinggi',
                        icon: Icons.notifications_active_rounded,
                        color: const Color(0xFFEF4444),
                        description: 'Masuk daftar pengumuman, tampil di dashboard depan (Orang Tua & Siswa), dan mengirimkan Notifikasi Push.',
                      ),
                      const SizedBox(height: 12),
                      
                      _buildPriorityInfoCard(
                        title: 'Sedang',
                        icon: Icons.dashboard_rounded,
                        color: AppTheme.gold,
                        description: 'Masuk daftar pengumuman, dan akan selalu tampil di menu dashboard depan (Orang Tua & Siswa).',
                      ),
                      const SizedBox(height: 12),
                      
                      _buildPriorityInfoCard(
                        title: 'Rendah',
                        icon: Icons.list_alt_rounded,
                        color: AppTheme.softBlue,
                        description: 'Hanya masuk ke dalam menu daftar pengumuman tanpa sorotan khusus.',
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),

              // Close Button
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Tutup',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityInfoCard({
    required String title,
    required IconData icon,
    required Color color,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.grey100, width: 1),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
