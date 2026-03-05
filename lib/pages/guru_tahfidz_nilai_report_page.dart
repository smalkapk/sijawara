import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../theme.dart';
import '../services/tahfidz_service.dart';
import 'guru_tahfidz_nilai_form_page.dart';
import 'quran_page.dart' show allSurahs, Surah;
import 'surah_detail_page.dart';

class GuruTahfidzNilaiReportPage extends StatefulWidget {
  final Map<String, dynamic> studentData;
  final String className;

  const GuruTahfidzNilaiReportPage({
    super.key,
    required this.studentData,
    required this.className,
  });

  @override
  State<GuruTahfidzNilaiReportPage> createState() =>
      _GuruTahfidzNilaiReportPageState();
}

class _GuruTahfidzNilaiReportPageState
    extends State<GuruTahfidzNilaiReportPage> {
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
      final reports = await TahfidzService.getReports(studentId: _studentId);
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
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppTheme.primaryGreen),
                    )
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
                              return Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 16.0),
                                child:
                                    _buildReportCard(report, index),
                              );
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
                  widget.studentData['name']?.toString() ?? 'Detail Siswa',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
    final dateStr = DateFormat('d MMM yyyy', 'id_ID').format(report.setoranAt);

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
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryGreen.withOpacity(0.05) : AppTheme.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryGreen.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              : AppTheme.softShadow,
          border: Border.all(
            color: isSelected ? AppTheme.primaryGreen : AppTheme.grey100,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.gold.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.stars_rounded,
                        color: AppTheme.gold,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Capaian Hafalan',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.grey400,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Multi-surah: show each item with per-surah grade
            if (report.isMultiSurah) ...[
              _buildReportItem('Surah', ''),
              ...report.items.map((item) {
                final gColor = _gradeColor(item.grade);
                return Padding(
                  padding: const EdgeInsets.only(left: 8, top: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppTheme.primaryGreen,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${item.surahName} — Ayat ${item.ayatFrom}-${item.ayatTo}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                            height: 1.4,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: gColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          item.grade,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: gColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ] else ...[
              _buildReportItem('Surah', report.surahName),
              _buildDivider(),
              _buildReportItem('Ayat', report.ayatRange),
            ],
            _buildDivider(),
            if (report.isMultiSurah) ...[
              _buildReportItem('Predikat Nilai', ''),
              ...report.items.map((item) {
                final gColor = _gradeColor(item.grade);
                return Padding(
                  padding: const EdgeInsets.only(left: 8, top: 4),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: gColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          item.grade,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: gColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        item.surahName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ] else
              _buildReportItem(
                'Predikat Nilai',
                report.grade,
              ),
            _buildDivider(),
            _buildReportItem(
              'Catatan Guru',
              report.notes.isNotEmpty ? report.notes : '-',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.grey400,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Container(
        height: 1,
        color: AppTheme.grey100,
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

  void _openSurahDetail(Surah surah, {int initialAyat = 1}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SurahDetailPage(
          surahNumber: surah.number,
          surahName: surah.name,
          arabicName: surah.arabicName,
          initialAyat: initialAyat,
          disableLongPress: true,
        ),
      ),
    );
  }

  void _showSurahPickerBottomSheet(Surah completedSurah) {
    int selectedIndex = completedSurah.number - 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Handle bar ──
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // ── Icon ──
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: AppTheme.primaryGreen,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // ── Title ──
                  const Text(
                    'Membuka Surat Lainnya?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.darkGreen,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  // ── Subtitle ──
                  Text(
                    'Berdasarkan laporan terakhir, siswa sudah selesai '
                    'menghafalkan surat ${completedSurah.name}, '
                    'ingin membuka surat lainnya?',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  // ── Surah Picker (wheel) ──
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.grey100),
                    ),
                    child: CupertinoPicker(
                      scrollController: FixedExtentScrollController(
                        initialItem: selectedIndex,
                      ),
                      itemExtent: 48,
                      magnification: 1.15,
                      squeeze: 0.85,
                      useMagnifier: true,
                      selectionOverlay: Container(
                        decoration: BoxDecoration(
                          border: Border.symmetric(
                            horizontal: BorderSide(
                              color: AppTheme.primaryGreen.withValues(alpha: 0.2),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                      onSelectedItemChanged: (index) {
                        setModalState(() => selectedIndex = index);
                      },
                      children: allSurahs.map((surah) {
                        return Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 30,
                                child: Text(
                                  '${surah.number}.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.grey400,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                surah.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                surah.arabicName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.grey400,
                                  fontFamily: 'Amiri',
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // ── Buka Surat button ──
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      final surah = allSurahs[selectedIndex];
                      _openSurahDetail(surah);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        gradient: AppTheme.mainGradient,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        boxShadow: AppTheme.greenGlow,
                      ),
                      child: const Text(
                        'Buka Surat',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // ── Tetap di surat ini button ──
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      _openSurahDetail(completedSurah);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        border: Border.all(color: AppTheme.grey400),
                      ),
                      child: Text(
                        'Tetap Buka ${completedSurah.name}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.black,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showDeleteBottomSheet(TahfidzSetoran report) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        bool isDeleting = false;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Handle bar ──
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // ── Icon ──
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.delete_forever_rounded,
                      color: Colors.red.shade400,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // ── Title ──
                  const Text(
                    'Hapus Capaian Hafalan Siswa?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  // ── Subtitle ──
                  Text(
                    report.isMultiSurah
                        ? 'Capaian yang dipilih pada ${report.items.length} surat (${report.surahName}), lanjutkan?'
                        : 'Capaian yang dipilih pada surat ${report.surahName}, ayat ${report.ayatFrom} - ${report.ayatTo}, lanjutkan?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // ── Hapus button ──
                  GestureDetector(
                    onTap: isDeleting
                        ? null
                        : () async {
                            setModalState(() => isDeleting = true);
                            try {
                              await TahfidzService.deleteSetoran(
                                report.id,
                                groupId: report.groupId,
                              );
                              if (ctx.mounted) Navigator.pop(ctx);
                              if (mounted) {
                                setState(() => _selectedReportIndex = null);
                                _loadReports();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Capaian berhasil dihapus'),
                                    backgroundColor: AppTheme.primaryGreen,
                                  ),
                                );
                              }
                            } catch (e) {
                              setModalState(() => isDeleting = false);
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Gagal menghapus: $e'),
                                    backgroundColor: Colors.red.shade400,
                                  ),
                                );
                              }
                            }
                          },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade500,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (isDeleting)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          else
                            const Icon(Icons.delete_rounded,
                                color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            isDeleting ? 'Menghapus...' : 'Hapus Capaian',
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
                  const SizedBox(height: 40)
                ],
              ),
            );
          },
        );
      },
    );
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
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // ── Buka Al-Quran button (hidden when card selected) ──
            if (_reports.isNotEmpty && !hasSelection)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    final lastReport = _reports.first;
                    final surahNum = lastReport.surahNumber;
                    final surahData = allSurahs.firstWhere(
                      (s) => s.number == surahNum,
                      orElse: () => allSurahs.first,
                    );
                    if (lastReport.ayatTo >= surahData.ayatCount) {
                      _showSurahPickerBottomSheet(surahData);
                    } else {
                      _openSurahDetail(surahData, initialAyat: lastReport.ayatTo);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.white,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      border: Border.all(color: AppTheme.primaryGreen, width: 1.5),
                    ),
                    child: const Icon(
                      Icons.menu_book_rounded,
                      color: AppTheme.primaryGreen,
                      size: 20,
                    ),
                  ),
                ),
              ),
            // ── Hapus Laporan button (shown when card selected) ──
            if (hasSelection)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    final sel = _reports[_selectedReportIndex!];
                    _showDeleteBottomSheet(sel);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.white,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      border: Border.all(color: Colors.red.shade400, width: 1.5),
                    ),
                    child: Icon(
                      Icons.delete_rounded,
                      color: Colors.red.shade400,
                      size: 20,
                    ),
                  ),
                ),
              ),
            // ── Tambah / Edit Laporan button ──
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
                    formData['surahName'] = sel.surahName;
                    formData['ayatRange'] = sel.ayatRange;
                    formData['ayat_from'] = sel.ayatFrom;
                    formData['ayat_to'] = sel.ayatTo;
                    formData['grade'] = sel.grade;
                    formData['notes'] = sel.notes;
                    // Pass items list for multi-surah editing
                    formData['items'] = sel.items.map((i) => i.toJson()).toList();
                    editing = true;
                  }

                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GuruTahfidzNilaiFormPage(
                        isEditing: editing,
                        initialData: editing ? formData : null,
                        studentData: widget.studentData,
                        className: widget.className,
                      ),
                    ),
                  );

                  if (mounted) {
                    setState(() => _selectedReportIndex = null);
                    if (result == true) {
                      _loadReports();
                    }
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: hasSelection
                        ? null 
                        : AppTheme.mainGradient,
                    color: hasSelection ? AppTheme.gold : null,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    boxShadow: hasSelection
                        ? [BoxShadow(color: AppTheme.gold.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))]
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
