import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../services/tahfidz_service.dart';

class GuruKelasTahfidzFormPage extends StatefulWidget {
  final bool isEditing;
  final Map<String, dynamic>? initialData;

  const GuruKelasTahfidzFormPage({
    super.key,
    this.isEditing = false,
    this.initialData,
  });

  @override
  State<GuruKelasTahfidzFormPage> createState() =>
      _GuruKelasTahfidzFormPageState();
}

class _GuruKelasTahfidzFormPageState extends State<GuruKelasTahfidzFormPage> {
  final _surahController = TextEditingController();
  final _ayatFromController = TextEditingController();
  final _ayatToController = TextEditingController();
  final _noteController = TextEditingController();
  String _selectedGrade = 'A';
  int? _selectedSurahNumber;
  bool _isSaving = false;

  final List<String> _gradeOptions = ['A', 'B+', 'B', 'C', 'D'];

  @override
  void initState() {
    super.initState();
    if (widget.isEditing && widget.initialData != null) {
      _surahController.text = widget.initialData!['last_surah'] ?? '';
      _selectedSurahNumber = widget.initialData!['surah_number'] as int?;
      _selectedGrade = widget.initialData!['grade'] ?? 'A';
      _noteController.text = widget.initialData!['note'] ?? '';

      // Ayat: parse from separate fields or "from-to" string
      if (widget.initialData!['ayat_from'] != null) {
        _ayatFromController.text =
            widget.initialData!['ayat_from'].toString();
        _ayatToController.text =
            widget.initialData!['ayat_to'].toString();
      } else if (widget.initialData!['ayat'] != null) {
        final parts = widget.initialData!['ayat'].toString().split('-');
        if (parts.length == 2) {
          _ayatFromController.text = parts[0].trim();
          _ayatToController.text = parts[1].trim();
        }
      }
    }
  }

  @override
  void dispose() {
    _surahController.dispose();
    _ayatFromController.dispose();
    _ayatToController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _saveForm() async {
    HapticFeedback.mediumImpact();

    // Validasi surah
    int? surahNum = _selectedSurahNumber;
    surahNum ??= findSurahNumber(_surahController.text);
    if (surahNum == null || _surahController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Nama surah tidak dikenali'),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    // Validasi ayat
    final ayatFrom = int.tryParse(_ayatFromController.text.trim());
    final ayatTo = int.tryParse(_ayatToController.text.trim());
    if (ayatFrom == null || ayatTo == null || ayatFrom <= 0 || ayatTo <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Ayat dari dan sampai harus diisi angka'),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final studentId = widget.initialData?['student_id'];
    if (studentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Data siswa tidak valid'),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
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
      final sid = studentId is int
          ? studentId
          : int.parse(studentId.toString());

      if (widget.isEditing && widget.initialData?['id'] != null) {
        await TahfidzService.updateSetoran(
          id: widget.initialData!['id'].toString(),
          studentId: sid,
          surahNumber: surahNum,
          ayatFrom: ayatFrom,
          ayatTo: ayatTo,
          grade: _selectedGrade,
          notes: _noteController.text.trim(),
        );
      } else {
        await TahfidzService.addSetoran(
          studentId: sid,
          surahNumber: surahNum,
          ayatFrom: ayatFrom,
          ayatTo: ayatTo,
          grade: _selectedGrade,
          notes: _noteController.text.trim(),
        );
      }

      if (mounted) {
        Navigator.pop(context); // Close loading
        Navigator.pop(context, true); // Go back with success
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isEditing
                ? 'Laporan berhasil diperbarui'
                : 'Laporan berhasil disimpan'),
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
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan: $e'),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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
                    _buildSurahAutocomplete(),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInputField(
                            'Ayat Dari',
                            _ayatFromController,
                            Icons.numbers_rounded,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildInputField(
                            'Ayat Sampai',
                            _ayatToController,
                            Icons.numbers_rounded,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
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

  Widget _buildInputField(
    String label,
    TextEditingController controller,
    IconData icon, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
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
                color: Colors.black.withValues(alpha: 0.02),
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
                  keyboardType: keyboardType,
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

  /// Surah autocomplete input
  Widget _buildSurahAutocomplete() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Nama Surah',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Autocomplete<MapEntry<int, String>>(
          initialValue: TextEditingValue(text: _surahController.text),
          optionsBuilder: (textEditingValue) {
            final query = textEditingValue.text.toLowerCase().trim();
            if (query.isEmpty) return surahNames.entries;
            return surahNames.entries.where(
              (e) => e.value.toLowerCase().contains(query),
            );
          },
          displayStringForOption: (option) => option.value,
          onSelected: (option) {
            _selectedSurahNumber = option.key;
            _surahController.text = option.value;
          },
          fieldViewBuilder:
              (context, textController, focusNode, onFieldSubmitted) {
            // Sync if initialValue was set
            if (textController.text.isEmpty &&
                _surahController.text.isNotEmpty) {
              textController.text = _surahController.text;
            }
            return Container(
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: AppTheme.grey100, width: 1),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.menu_book_rounded,
                      color: AppTheme.primaryGreen, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: textController,
                      focusNode: focusNode,
                      onChanged: (val) {
                        _surahController.text = val;
                        _selectedSurahNumber = null;
                      },
                      decoration: InputDecoration(
                        hintText: 'Cari nama surah...',
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: AppTheme.grey400,
                          fontWeight: FontWeight.w500,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final opt = options.elementAt(index);
                      return ListTile(
                        dense: true,
                        title: Text(
                          '${opt.key}. ${opt.value}',
                          style: const TextStyle(fontSize: 14),
                        ),
                        onTap: () => onSelected(opt),
                      );
                    },
                  ),
                ),
              ),
            );
          },
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
                        color: AppTheme.gold.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
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
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: SafeArea(
        child: GestureDetector(
          onTap: _isSaving ? null : _saveForm,
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
