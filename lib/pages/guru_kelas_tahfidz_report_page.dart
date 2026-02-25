import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import 'guru_kelas_tahfidz_form_page.dart';

class GuruKelasTahfidzReportPage extends StatefulWidget {
  final Map<String, dynamic> studentData;

  const GuruKelasTahfidzReportPage({super.key, required this.studentData});

  @override
  State<GuruKelasTahfidzReportPage> createState() => _GuruKelasTahfidzReportPageState();
}

class _GuruKelasTahfidzReportPageState extends State<GuruKelasTahfidzReportPage> {
  int? _selectedReportIndex;

  final List<Map<String, dynamic>> dummyReports = const [
    {
      'date': '24 Feb 2026',
      'last_surah': 'Al-Mulk',
      'ayat': '1-10',
      'grade': 'A',
      'note': 'Alhamdulillah hafalan sudah cukup lancar, namun perlu lebih teliti lagi pada bagian hukum tajwid tertentu. Terus murajaah di rumah.'
    },
    {
      'date': '20 Feb 2026',
      'last_surah': 'At-Tahrim',
      'ayat': '1-12',
      'grade': 'B+',
      'note': 'Hafalan baik, perhatikan panjang pendeknya.'
    },
    {
      'date': '15 Feb 2026',
      'last_surah': 'At-Talaq',
      'ayat': '1-12',
      'grade': 'A',
      'note': 'Sangat bagus, makhraj dan tajwid jelas.'
    },
  ];

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
                  children: [
                    _buildStudentProfile(),
                    const SizedBox(height: 24),
                    ...dummyReports.asMap().entries.map((entry) {
                      final index = entry.key;
                      final report = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: _buildReportCard(report, index),
                      );
                    }),
                    const SizedBox(height: 100), // Bottom padding for FAB/Buttons
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
                  'Detail Siswa',
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

  Widget _buildStudentProfile() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.mainGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.greenGlow,
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                widget.studentData['name'][0],
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.studentData['name'],
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'NIS: ${widget.studentData['nis']}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report, int index) {
    final isSelected = _selectedReportIndex == index;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          if (_selectedReportIndex == index) {
            _selectedReportIndex = null; // deselect
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
                  report['date'],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.grey400,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildReportItem('Surah', report['last_surah']),
            _buildDivider(),
            _buildReportItem('Ayat', report['ayat']),
            _buildDivider(),
            _buildReportItem('Predikat Nilai', report['grade']),
            _buildDivider(),
            _buildReportItem(
              'Catatan Guru',
              report['note'],
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

  Widget _buildBottomActions(BuildContext context) {
    final hasSelection = _selectedReportIndex != null;

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
            Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  if (hasSelection) {
                    final selectedData = dummyReports[_selectedReportIndex!];
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GuruKelasTahfidzFormPage(
                          isEditing: true,
                          initialData: {
                            ...widget.studentData,
                            ...selectedData,
                          },
                        ),
                      ),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GuruKelasTahfidzFormPage(
                          isEditing: false,
                          initialData: widget.studentData,
                        ),
                      ),
                    );
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

