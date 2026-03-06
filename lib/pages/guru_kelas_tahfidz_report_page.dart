import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../theme.dart';
import '../widgets/skeleton_loader.dart';
import '../services/tahfidz_service.dart';
import 'guru_kelas_tahfidz_form_page.dart';

class GuruKelasTahfidzReportPage extends StatefulWidget {
  final Map<String, dynamic> studentData;

  const GuruKelasTahfidzReportPage({super.key, required this.studentData});

  @override
  State<GuruKelasTahfidzReportPage> createState() =>
      _GuruKelasTahfidzReportPageState();
}

class _GuruKelasTahfidzReportPageState
    extends State<GuruKelasTahfidzReportPage> {
  int? _selectedReportIndex;
  List<TahfidzSetoran> _reports = [];
  bool _isLoading = true;

  int get _studentId =>
      widget.studentData['student_id'] is int
          ? widget.studentData['student_id']
          : int.parse(widget.studentData['student_id'].toString());

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);
    try {
      final reports =
          await TahfidzService.getReports(studentId: _studentId);
      if (mounted) {
        setState(() {
          _reports = reports;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat data: $e'),
            backgroundColor: Colors.red.shade400,
          ),
        );
      }
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
              child: _isLoading
                ? const PublicSpeakingSkeleton()
                : RefreshIndicator(
                      color: AppTheme.primaryGreen,
                      onRefresh: _loadReports,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 16),
                        child: Column(
                          children: [
                            if (_reports.isEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 40),
                                child: Column(
                                  children: [
                                    Icon(Icons.menu_book_rounded,
                                        size: 64, color: AppTheme.grey400),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Belum ada setoran',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.grey400,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              ..._reports.asMap().entries.map((entry) {
                                final index = entry.key;
                                final report = entry.value;
                                return _buildReportCard(report, index);
                              }),
                            const SizedBox(height: 100),
                          ],
                        ),
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
                      Icons.history_edu_rounded,
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
                  widget.studentData['name'] ?? 'Detail Siswa',
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

  Widget _buildReportCard(TahfidzSetoran report, int index) {
    final isSelected = _selectedReportIndex == index;
    final dateStr = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(report.setoranAt);
    final setoranNo = _reports.length - index;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          if (_selectedReportIndex == index) {
            _selectedReportIndex = null;
          } else {
            _selectedReportIndex = index;
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryGreen.withValues(alpha: 0.05)
              : AppTheme.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: isSelected ? AppTheme.primaryGreen : AppTheme.grey100,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Setoran $setoranNo',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dateStr,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.grey400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: AppTheme.grey100),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                children: [
                  if (report.isMultiSurah && report.items.isNotEmpty)
                    for (int i = 0; i < report.items.length; i++) ...[
                      if (i > 0) const SizedBox(height: 6),
                      _buildSetoranItemRow(
                        surahName: report.items[i].surahName,
                        ayatText:
                            'Ayat ${report.items[i].ayatFrom} - ${report.items[i].ayatTo}',
                        grade: report.items[i].grade,
                      ),
                    ]
                  else
                    _buildSetoranItemRow(
                      surahName: report.surahName,
                      ayatText: 'Ayat ${report.ayatRange}',
                      grade: report.grade,
                    ),
                  if (report.notes.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(height: 1, color: AppTheme.grey100),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Catatan Guru: ${report.notes}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSetoranItemRow({
    required String surahName,
    required String ayatText,
    required String grade,
  }) {
    final gColor = _gradeColor(grade);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.menu_book_rounded,
              color: AppTheme.primaryGreen,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  surahName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  ayatText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.grey400,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: gColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              grade,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: gColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

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

  Widget _buildBottomActions(BuildContext context) {
    final hasSelection =
        _selectedReportIndex != null && _selectedReportIndex! < _reports.length;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
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
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  HapticFeedback.lightImpact();
                  Map<String, dynamic> formData = {
                    ...widget.studentData,
                  };
                  bool editing = false;

                  if (hasSelection) {
                    final sel = _reports[_selectedReportIndex!];
                    formData['id'] = sel.id;
                    formData['group_id'] = sel.groupId;
                    formData['surah_number'] = sel.surahNumber;
                    formData['last_surah'] = sel.surahName;
                    formData['ayat'] = sel.ayatRange;
                    formData['ayat_from'] = sel.ayatFrom;
                    formData['ayat_to'] = sel.ayatTo;
                    formData['grade'] = sel.grade;
                    formData['note'] = sel.notes;
                    // Pass items list for multi-surah editing
                    formData['items'] = sel.items.map((i) => i.toJson()).toList();
                    editing = true;
                  }

                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GuruKelasTahfidzFormPage(
                        isEditing: editing,
                        initialData: formData,
                      ),
                    ),
                  );

                  if (result == true && mounted) {
                    _selectedReportIndex = null;
                    _loadReports();
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: hasSelection
                        ? null // Example: Use gold for edit
                        : AppTheme.mainGradient,
                    color: hasSelection ? AppTheme.gold : null,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    boxShadow: hasSelection
                        ? [BoxShadow(color: AppTheme.gold.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))]
                        : AppTheme.greenGlow,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        hasSelection ? Icons.edit_document : Icons.add_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        hasSelection ? 'Edit Laporan' : 'Tambah Laporan',
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
          ],
        ),
      ),
    );
  }
}

