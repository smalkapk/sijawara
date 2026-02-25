import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';

class GuruKelasTahfidzFormPage extends StatefulWidget {
  final bool isEditing;
  final Map<String, dynamic>? initialData;

  const GuruKelasTahfidzFormPage({
    super.key,
    this.isEditing = false,
    this.initialData,
  });

  @override
  State<GuruKelasTahfidzFormPage> createState() => _GuruKelasTahfidzFormPageState();
}

class _GuruKelasTahfidzFormPageState extends State<GuruKelasTahfidzFormPage> {
  final _surahController = TextEditingController();
  final _ayatController = TextEditingController();
  final _noteController = TextEditingController();
  String _selectedGrade = 'A';

  final List<String> _gradeOptions = ['A', 'B+', 'B', 'C+', 'C', 'D'];

  @override
  void initState() {
    super.initState();
    if (widget.isEditing && widget.initialData != null) {
      _surahController.text = widget.initialData!['last_surah'] ?? '';
      _ayatController.text = widget.initialData!['ayat'] ?? '';
      _selectedGrade = widget.initialData!['grade'] ?? 'A';
      _noteController.text = widget.initialData!['note'] ?? '';
    }
  }

  @override
  void dispose() {
    _surahController.dispose();
    _ayatController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _saveForm() {
    HapticFeedback.mediumImpact();
    // Simulate saving delay
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryGreen),
      ),
    );

    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        Navigator.pop(context); // Close loading
        Navigator.pop(context); // Go back to report page
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Laporan berhasil disimpan'),
            backgroundColor: AppTheme.primaryGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    });
  }

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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInputField('Nama Surah', _surahController, Icons.menu_book_rounded),
                    const SizedBox(height: 16),
                    _buildInputField('Ayat', _ayatController, Icons.numbers_rounded),
                    const SizedBox(height: 16),
                    
                    const Text(
                      'Predikat Nilai',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildGradeSelector(),
                    const SizedBox(height: 16),

                    _buildInputField('Catatan Guru', _noteController, Icons.notes_rounded, maxLines: 5),

                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomActions(context),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final title = widget.isEditing ? 'Edit Laporan' : 'Input Tahfidz';

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
                      Icons.edit_document,
                      size: 14,
                      color: AppTheme.gold,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Laporan Tahfidz',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  title,
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
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: AppTheme.grey100, width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            crossAxisAlignment: maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: [
              Padding(
                padding: EdgeInsets.only(top: maxLines > 1 ? 12.0 : 0.0),
                child: Icon(icon, color: AppTheme.primaryGreen, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: controller,
                  maxLines: maxLines,
                  decoration: InputDecoration(
                    hintText: 'Masukkan $label...',
                    hintStyle: TextStyle(
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
      ],
    );
  }

  Widget _buildGradeSelector() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _gradeOptions.map((grade) {
        final isSelected = _selectedGrade == grade;
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedGrade = grade;
            });
            HapticFeedback.selectionClick();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.gold : AppTheme.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppTheme.gold.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
              border: Border.all(
                color: isSelected ? AppTheme.gold : AppTheme.grey200,
                width: 1,
              ),
            ),
            child: Text(
              grade,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isSelected ? AppTheme.white : AppTheme.grey600,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBottomActions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: SafeArea(
        child: GestureDetector(
          onTap: _saveForm,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: AppTheme.mainGradient,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              boxShadow: AppTheme.greenGlow,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.save_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  'Simpan Laporan',
                  style: TextStyle(
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
}
