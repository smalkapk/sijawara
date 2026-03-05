import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../services/tahfidz_service.dart';
import 'quran_page.dart' show allSurahs;

class GuruTahfidzNilaiFormPage extends StatefulWidget {
  final bool isEditing;
  final Map<String, dynamic>? initialData;
  final Map<String, dynamic>? studentData;
  final String? className;

  const GuruTahfidzNilaiFormPage({
    super.key,
    this.isEditing = false,
    this.initialData,
    this.studentData,
    this.className,
  });

  @override
  State<GuruTahfidzNilaiFormPage> createState() =>
      _GuruTahfidzNilaiFormPageState();
}

class _GuruTahfidzNilaiFormPageState extends State<GuruTahfidzNilaiFormPage> {
  final _surahController = TextEditingController();
  final _ayatFromController = TextEditingController();
  final _ayatToController = TextEditingController();
  final _noteController = TextEditingController();
  final FocusNode _ayatToFocusNode = FocusNode();
  String _selectedGrade = 'A';
  int? _selectedSurahNumber;
  bool _isSaving = false;

  // Multi-surah items
  final List<SetoranItem> _surahItems = [];
  bool get _isMultiSurahMode => _surahItems.isNotEmpty;

  final List<String> _gradeOptions = ['A', 'B+', 'B', 'C', 'D'];

  // Full list of surahs from tahfidz_service
  final List<String> _surahNames = surahNames.values.toList();

  /// Get max ayat count for the currently selected surah
  int? get _maxAyat {
    if (_selectedSurahNumber == null) return null;
    try {
      final surah = allSurahs.firstWhere((s) => s.number == _selectedSurahNumber);
      return surah.ayatCount;
    } catch (_) {
      return null;
    }
  }

  /// Validate and clamp ayatTo to the max ayat count of the selected surah
  void _validateAyatTo() {
    final max = _maxAyat;
    if (max == null) return;
    final val = int.tryParse(_ayatToController.text.trim());
    if (val != null && val > max) {
      _ayatToController.text = max.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ayat sampai disesuaikan ke $max (ayat maksimal surat ini)'),
          backgroundColor: AppTheme.gold,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _ayatToFocusNode.addListener(() {
      if (!_ayatToFocusNode.hasFocus) {
        _validateAyatTo();
      }
    });
    if (widget.isEditing && widget.initialData != null) {
      _selectedGrade = widget.initialData!['grade'] ?? 'A';
      _noteController.text = widget.initialData!['notes'] ?? '';

      // Multi-surah editing: populate _surahItems from items list
      final items = widget.initialData!['items'];
      if (items != null && items is List && items.length > 1) {
        _surahItems.addAll(
          items.map((e) => SetoranItem.fromJson(e as Map<String, dynamic>)),
        );
      } else if (items != null && items is List && items.length == 1) {
        // Single-surah editing: populate fields normally, with grade from item
        final item = items[0] as Map<String, dynamic>;
        _surahController.text = surahNames[item['surah_number'] is int
            ? item['surah_number']
            : int.parse(item['surah_number'].toString())] ?? '';
        _selectedSurahNumber = item['surah_number'] is int
            ? item['surah_number']
            : int.parse(item['surah_number'].toString());
        _ayatFromController.text = item['ayat_from'].toString();
        _ayatToController.text = item['ayat_to'].toString();
        if (item['grade'] != null && (item['grade'] as String).isNotEmpty) {
          _selectedGrade = item['grade'] as String;
        }
      } else {
        // Legacy: no items array
        _surahController.text = widget.initialData!['surahName'] ?? '';
        _selectedSurahNumber = widget.initialData!['surah_number'] as int?;

        if (widget.initialData!['ayat_from'] != null) {
          _ayatFromController.text = widget.initialData!['ayat_from'].toString();
          _ayatToController.text = widget.initialData!['ayat_to'].toString();
        } else if (widget.initialData!['ayatRange'] != null) {
          final parts = widget.initialData!['ayatRange'].toString().split('-');
          if (parts.length == 2) {
            _ayatFromController.text = parts[0].trim();
            _ayatToController.text = parts[1].trim();
          } else {
            _ayatFromController.text = widget.initialData!['ayatRange'].toString();
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _surahController.dispose();
    _ayatFromController.dispose();
    _ayatToController.dispose();
    _ayatToFocusNode.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _saveForm() async {
    HapticFeedback.mediumImpact();

    // Build surahs list from multi-surah items or single fields
    List<SetoranItem> surahs;

    if (_isMultiSurahMode) {
      surahs = List.from(_surahItems);
    } else {
      // Single-surah: validate surah + ayat fields
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

      _validateAyatTo();

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

      surahs = [SetoranItem(surahNumber: surahNum, ayatFrom: ayatFrom, ayatTo: ayatTo, grade: _selectedGrade)];
    }

    final studentId = widget.studentData?['student_id'];
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
          groupId: widget.initialData!['group_id']?.toString(),
          studentId: sid,
          surahs: surahs,
          grade: _selectedGrade,
          notes: _noteController.text.trim(),
        );
      } else {
        await TahfidzService.addSetoran(
          studentId: sid,
          surahs: surahs,
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
                    if (widget.studentData != null) _buildStudentInfo(),
                    if (widget.studentData != null) const SizedBox(height: 24),

                    // ── Multi-surah cards (when items exist) ──
                    if (_isMultiSurahMode) ...[
                      const Text(
                        'Surah yang disetorkan',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._surahItems.asMap().entries.map(
                        (entry) => _buildSurahItemCard(entry.key, entry.value),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // ── Single-surah fields (when no items) ──
                    if (!_isMultiSurahMode) ...[
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
                              focusNode: _ayatToFocusNode,
                              hintSuffix: _maxAyat != null ? ' (maks $_maxAyat)' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],

                    // ── Tambah Surah button ──
                    _buildAddSurahButton(),
                    const SizedBox(height: 16),

                    // ── Grade selector: hanya tampil di single-surah mode ──
                    if (!_isMultiSurahMode) ...[
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
                    ],

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

  Widget _buildStudentInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.white,
              shape: BoxShape.circle,
              boxShadow: AppTheme.softShadow,
            ),
            child: const Icon(Icons.person_outline_rounded, color: AppTheme.primaryGreen),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.studentData?['name'] ?? 'Siswa',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'NIS: ${widget.studentData?['nis']} • ${widget.className}',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
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
    FocusNode? focusNode,
    String? hintSuffix,
  }) {
    final hintText = hintSuffix != null
        ? 'Masukkan $label...$hintSuffix'
        : 'Masukkan $label...';
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
                  focusNode: focusNode,
                  maxLines: maxLines,
                  keyboardType: keyboardType,
                  decoration: InputDecoration(
                    hintText: hintText,
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
        Autocomplete<String>(
          initialValue: TextEditingValue(text: _surahController.text),
          optionsBuilder: (textEditingValue) {
            final query = textEditingValue.text.toLowerCase().trim();
            if (query.isEmpty) return _surahNames;
            return _surahNames.where(
              (e) => e.toLowerCase().contains(query),
            );
          },
          onSelected: (option) {
            _surahController.text = option;
            _selectedSurahNumber = findSurahNumber(option);
            setState(() {});
            _validateAyatTo();
          },
          fieldViewBuilder:
              (context, textController, focusNode, onFieldSubmitted) {
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
                    color: Colors.black.withOpacity(0.02),
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
                        _selectedSurahNumber = findSurahNumber(val);
                        setState(() {});
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
                          opt,
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

  // ── Grade color helper ──
  Color _gradeColor(String grade) {
    switch (grade) {
      case 'A':  return const Color(0xFF7C3AED);
      case 'B+': return const Color(0xFF3B82F6);
      case 'B':  return const Color(0xFF059669);
      case 'C':  return const Color(0xFFF59E0B);
      case 'D':  return const Color(0xFFEF4444);
      default:   return AppTheme.grey400;
    }
  }

  // ── Multi-surah: item card (tappable to edit) ──
  Widget _buildSurahItemCard(int index, SetoranItem item) {
    final gColor = _gradeColor(item.grade);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _showEditSurahBottomSheet(index, item);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.menu_book_rounded,
                  color: AppTheme.primaryGreen, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.surahName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Ayat ${item.ayatFrom} - ${item.ayatTo}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.grey400,
                    ),
                  ),
                ],
              ),
            ),
            // Grade badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: gColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: gColor.withOpacity(0.3)),
              ),
              child: Text(
                item.grade,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: gColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _surahItems.removeAt(index));
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.close_rounded,
                    color: Colors.red.shade400, size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── "Tambah Surah" button ──
  Widget _buildAddSurahButton() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        // If single-surah fields have values, convert to item first
        if (!_isMultiSurahMode) {
          final surahNum =
              _selectedSurahNumber ?? findSurahNumber(_surahController.text);
          final ayatFrom = int.tryParse(_ayatFromController.text.trim());
          final ayatTo = int.tryParse(_ayatToController.text.trim());
          if (surahNum != null &&
              ayatFrom != null &&
              ayatTo != null &&
              ayatFrom > 0 &&
              ayatTo > 0) {
            setState(() {
              _surahItems.add(SetoranItem(
                surahNumber: surahNum,
                ayatFrom: ayatFrom,
                ayatTo: ayatTo,
                grade: _selectedGrade,
              ));
              _surahController.clear();
              _ayatFromController.clear();
              _ayatToController.clear();
              _selectedSurahNumber = null;
            });
          }
        }
        _showAddSurahBottomSheet();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.primaryGreen.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.primaryGreen.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded,
                color: AppTheme.primaryGreen, size: 20),
            const SizedBox(width: 8),
            Text(
              _isMultiSurahMode ? 'Tambah Surah Lain' : 'Tambah Surah',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Grade mini selector for bottom sheets ──
  Widget _buildGradeMiniSelector(String selected, void Function(String) onSelect, void Function(VoidCallback) setSheet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Predikat Nilai',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _gradeOptions.map((grade) {
            final isSelected = selected == grade;
            final gColor = _gradeColor(grade);
            return GestureDetector(
              onTap: () {
                setSheet(() => onSelect(grade));
                HapticFeedback.selectionClick();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  color: isSelected ? gColor : AppTheme.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? gColor : AppTheme.grey200,
                    width: 1,
                  ),
                  boxShadow: isSelected
                      ? [BoxShadow(color: gColor.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))]
                      : null,
                ),
                child: Text(
                  grade,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? Colors.white : AppTheme.grey600,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Bottom sheet for adding a surah item ──
  void _showAddSurahBottomSheet() {
    final bsSurahController = TextEditingController();
    final bsAyatFromController = TextEditingController();
    final bsAyatToController = TextEditingController();
    int? bsSelectedSurahNumber;
    String bsGrade = _surahItems.isNotEmpty ? _surahItems.last.grade : _selectedGrade;
    final surahList = surahNames.values.toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            // Max ayat for the selected surah in bottom sheet
            int? bsMaxAyat;
            if (bsSelectedSurahNumber != null) {
              try {
                final surah = allSurahs
                    .firstWhere((s) => s.number == bsSelectedSurahNumber);
                bsMaxAyat = surah.ayatCount;
              } catch (_) {}
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: AppTheme.white,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Handle bar
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Tambah Surah',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Surah autocomplete
                      const Text(
                        'Nama Surah',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Autocomplete<String>(
                        optionsBuilder: (textEditingValue) {
                          final q = textEditingValue.text.toLowerCase().trim();
                          if (q.isEmpty) return surahList;
                          return surahList
                              .where((e) => e.toLowerCase().contains(q));
                        },
                        onSelected: (option) {
                          bsSurahController.text = option;
                          bsSelectedSurahNumber = findSurahNumber(option);
                          setModalState(() {});
                        },
                        fieldViewBuilder: (ctx2, textController, focusNode,
                            onFieldSubmitted) {
                          return Container(
                            decoration: BoxDecoration(
                              color: AppTheme.bgColor,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: AppTheme.grey100, width: 1),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 2),
                            child: Row(
                              children: [
                                const Icon(Icons.menu_book_rounded,
                                    color: AppTheme.primaryGreen, size: 18),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    controller: textController,
                                    focusNode: focusNode,
                                    onChanged: (val) {
                                      bsSurahController.text = val;
                                      bsSelectedSurahNumber =
                                          findSurahNumber(val);
                                      setModalState(() {});
                                    },
                                    decoration: InputDecoration(
                                      hintText: 'Cari nama surah...',
                                      hintStyle: TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.grey400,
                                      ),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              vertical: 14),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        optionsViewBuilder: (ctx2, onSelected, options) {
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 4,
                              borderRadius: BorderRadius.circular(12),
                              child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxHeight: 180),
                                child: ListView.builder(
                                  padding: EdgeInsets.zero,
                                  shrinkWrap: true,
                                  itemCount: options.length,
                                  itemBuilder: (ctx3, index) {
                                    final opt = options.elementAt(index);
                                    return ListTile(
                                      dense: true,
                                      title: Text(opt,
                                          style:
                                              const TextStyle(fontSize: 13)),
                                      onTap: () => onSelected(opt),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),

                      // Ayat From & To
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Ayat Dari',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  decoration: BoxDecoration(
                                    color: AppTheme.bgColor,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                        color: AppTheme.grey100, width: 1),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 2),
                                  child: TextField(
                                    controller: bsAyatFromController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      hintText: 'Dari...',
                                      hintStyle: TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.grey400,
                                      ),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              vertical: 14),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  bsMaxAyat != null
                                      ? 'Ayat Sampai (maks $bsMaxAyat)'
                                      : 'Ayat Sampai',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  decoration: BoxDecoration(
                                    color: AppTheme.bgColor,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                        color: AppTheme.grey100, width: 1),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 2),
                                  child: TextField(
                                    controller: bsAyatToController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      hintText: 'Sampai...',
                                      hintStyle: TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.grey400,
                                      ),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              vertical: 14),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Grade selector
                      _buildGradeMiniSelector(bsGrade, (g) => bsGrade = g, setModalState),
                      const SizedBox(height: 20),

                      // Tambah button
                      GestureDetector(
                        onTap: () {
                          final sNum = bsSelectedSurahNumber ??
                              findSurahNumber(bsSurahController.text);
                          final aFrom = int.tryParse(
                              bsAyatFromController.text.trim());
                          var aTo = int.tryParse(
                              bsAyatToController.text.trim());

                          if (sNum == null ||
                              bsSurahController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                    const Text('Pilih surah terlebih dahulu'),
                                backgroundColor: Colors.red.shade400,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            );
                            return;
                          }
                          if (aFrom == null ||
                              aTo == null ||
                              aFrom <= 0 ||
                              aTo <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                    'Ayat dari dan sampai harus diisi'),
                                backgroundColor: Colors.red.shade400,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            );
                            return;
                          }
                          // Clamp ayat to max
                          if (bsMaxAyat != null && aTo > bsMaxAyat) {
                            aTo = bsMaxAyat;
                          }
                          Navigator.pop(ctx);
                          setState(() {
                            _surahItems.add(SetoranItem(
                              surahNumber: sNum,
                              ayatFrom: aFrom,
                              ayatTo: aTo!,
                              grade: bsGrade,
                            ));
                          });
                        },
                        child: Container(
                          width: double.infinity,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            gradient: AppTheme.mainGradient,
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMd),
                            boxShadow: AppTheme.greenGlow,
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_rounded,
                                  color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Tambah',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── Bottom sheet for editing an existing surah item ──
  void _showEditSurahBottomSheet(int index, SetoranItem item) {
    final bsSurahController = TextEditingController(text: item.surahName);
    final bsAyatFromController = TextEditingController(text: item.ayatFrom.toString());
    final bsAyatToController = TextEditingController(text: item.ayatTo.toString());
    int? bsSelectedSurahNumber = item.surahNumber;
    String bsGrade = item.grade.isNotEmpty ? item.grade : _selectedGrade;
    final surahList = surahNames.values.toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            int? bsMaxAyat;
            if (bsSelectedSurahNumber != null) {
              try {
                final surah = allSurahs
                    .firstWhere((s) => s.number == bsSelectedSurahNumber);
                bsMaxAyat = surah.ayatCount;
              } catch (_) {}
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: AppTheme.white,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Edit Surah',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Surah autocomplete
                      const Text(
                        'Nama Surah',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Autocomplete<String>(
                        initialValue: TextEditingValue(text: item.surahName),
                        optionsBuilder: (textEditingValue) {
                          final q = textEditingValue.text.toLowerCase().trim();
                          if (q.isEmpty) return surahList;
                          return surahList
                              .where((e) => e.toLowerCase().contains(q));
                        },
                        onSelected: (option) {
                          bsSurahController.text = option;
                          bsSelectedSurahNumber = findSurahNumber(option);
                          setModalState(() {});
                        },
                        fieldViewBuilder: (ctx2, textController, focusNode,
                            onFieldSubmitted) {
                          return Container(
                            decoration: BoxDecoration(
                              color: AppTheme.bgColor,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: AppTheme.grey100, width: 1),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 2),
                            child: Row(
                              children: [
                                const Icon(Icons.menu_book_rounded,
                                    color: AppTheme.primaryGreen, size: 18),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    controller: textController,
                                    focusNode: focusNode,
                                    onChanged: (val) {
                                      bsSurahController.text = val;
                                      bsSelectedSurahNumber =
                                          findSurahNumber(val);
                                      setModalState(() {});
                                    },
                                    decoration: InputDecoration(
                                      hintText: 'Cari nama surah...',
                                      hintStyle: TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.grey400,
                                      ),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              vertical: 14),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        optionsViewBuilder: (ctx2, onSelected, options) {
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 4,
                              borderRadius: BorderRadius.circular(12),
                              child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxHeight: 180),
                                child: ListView.builder(
                                  padding: EdgeInsets.zero,
                                  shrinkWrap: true,
                                  itemCount: options.length,
                                  itemBuilder: (ctx3, idx) {
                                    final opt = options.elementAt(idx);
                                    return ListTile(
                                      dense: true,
                                      title: Text(opt,
                                          style:
                                              const TextStyle(fontSize: 13)),
                                      onTap: () => onSelected(opt),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),

                      // Ayat From & To
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Ayat Dari',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  decoration: BoxDecoration(
                                    color: AppTheme.bgColor,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                        color: AppTheme.grey100, width: 1),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 2),
                                  child: TextField(
                                    controller: bsAyatFromController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      hintText: 'Dari...',
                                      hintStyle: TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.grey400,
                                      ),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              vertical: 14),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  bsMaxAyat != null
                                      ? 'Ayat Sampai (maks $bsMaxAyat)'
                                      : 'Ayat Sampai',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  decoration: BoxDecoration(
                                    color: AppTheme.bgColor,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                        color: AppTheme.grey100, width: 1),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 2),
                                  child: TextField(
                                    controller: bsAyatToController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      hintText: 'Sampai...',
                                      hintStyle: TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.grey400,
                                      ),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              vertical: 14),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Grade selector
                      _buildGradeMiniSelector(bsGrade, (g) => bsGrade = g, setModalState),
                      const SizedBox(height: 20),

                      // Simpan button
                      GestureDetector(
                        onTap: () {
                          final sNum = bsSelectedSurahNumber ??
                              findSurahNumber(bsSurahController.text);
                          final aFrom = int.tryParse(
                              bsAyatFromController.text.trim());
                          var aTo = int.tryParse(
                              bsAyatToController.text.trim());

                          if (sNum == null ||
                              bsSurahController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                    const Text('Pilih surah terlebih dahulu'),
                                backgroundColor: Colors.red.shade400,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            );
                            return;
                          }
                          if (aFrom == null ||
                              aTo == null ||
                              aFrom <= 0 ||
                              aTo <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                    'Ayat dari dan sampai harus diisi'),
                                backgroundColor: Colors.red.shade400,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            );
                            return;
                          }
                          if (bsMaxAyat != null && aTo > bsMaxAyat) {
                            aTo = bsMaxAyat;
                          }
                          Navigator.pop(ctx);
                          setState(() {
                            _surahItems[index] = SetoranItem(
                              id: item.id,
                              surahNumber: sNum,
                              ayatFrom: aFrom,
                              ayatTo: aTo!,
                              grade: bsGrade,
                            );
                          });
                        },
                        child: Container(
                          width: double.infinity,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            gradient: AppTheme.mainGradient,
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMd),
                            boxShadow: AppTheme.greenGlow,
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_rounded,
                                  color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Simpan Perubahan',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
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
              children: [
                if (_isSaving)
                  const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                else
                  const Icon(Icons.save_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Text(
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
