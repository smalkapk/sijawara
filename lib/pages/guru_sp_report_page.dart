import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import 'guru_sp_form_page.dart';

class GuruSpReportPage extends StatefulWidget {
  final Map<String, dynamic> studentData;

  const GuruSpReportPage(
      {super.key, required this.studentData});

  @override
  State<GuruSpReportPage> createState() => _GuruSpReportPageState();
}

class _GuruSpReportPageState extends State<GuruSpReportPage> {
  int? _selectedReportIndex;

  final List<Map<String, dynamic>> dummyReports = const [
    {
      'date': '24-02-2026',
      'jenis_sp': 'SP 1',
      'alasan': 'Terlambat masuk sekolah lebih dari 3 kali berturut-turut tanpa keterangan.',
      'tindakan': 'Pemanggilan orang tua dan pembinaan konseling.',
      'note': 'Siswa telah diberikan peringatan lisan sebelumnya. Orang tua sudah dihubungi.',
    },
    {
      'date': '10-01-2026',
      'jenis_sp': 'Peringatan Lisan',
      'alasan': 'Tidak mengerjakan tugas berturut-turut pada mata pelajaran Matematika.',
      'tindakan': 'Teguran lisan oleh guru mata pelajaran dan wali kelas.',
      'note': 'Siswa berjanji untuk memperbaiki motivasi belajarnya.',
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  children: [
                    ...dummyReports.asMap().entries.map((entry) {
                      final index = entry.key;
                      final report = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: _buildReportCard(report, index),
                      );
                    }),
                    const SizedBox(height: 100),
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
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 14,
                      color: AppTheme.gold,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Riwayat SP Siswa',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  widget.studentData['name'],
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
          color: isSelected
              ? AppTheme.primaryGreen.withOpacity(0.05)
              : AppTheme.white,
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
                      child: Icon(
                        Icons.warning_amber_rounded,
                        color: AppTheme.gold,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      report['jenis_sp'],
                      style: const TextStyle(
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
            _buildReportItem('Alasan/Pelanggaran', report['alasan']),
            _buildDivider(),
            _buildReportItem('Tindakan', report['tindakan']),
            _buildDivider(),
            _buildReportItem(
              'Catatan Tambahan',
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
                        builder: (_) => GuruSpFormPage(
                          isEditing: true,
                          initialData: selectedData,
                          studentData: widget.studentData,
                        ),
                      ),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GuruSpFormPage(
                          isEditing: false,
                          studentData: widget.studentData,
                        ),
                      ),
                    );
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: hasSelection ? null : AppTheme.mainGradient,
                    color: hasSelection ? AppTheme.gold : null,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    boxShadow: hasSelection
                        ? [
                            BoxShadow(
                                color: AppTheme.gold.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4))
                          ]
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
                        hasSelection ? 'Edit Laporan SP' : 'Tambah Laporan SP',
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
