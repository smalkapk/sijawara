import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../services/guru_evaluasi_service.dart';
import 'guru_evaluasi_form_page.dart';

class GuruEvaluasiReportPage extends StatefulWidget {
  final Map<String, dynamic> studentData;

  const GuruEvaluasiReportPage({
    super.key,
    required this.studentData,
  });

  @override
  State<GuruEvaluasiReportPage> createState() => _GuruEvaluasiReportPageState();
}

class _GuruEvaluasiReportPageState extends State<GuruEvaluasiReportPage> {
  int? _selectedReportIndex;
  List<GuruEvaluasiReport> _reports = [];
  bool _isLoading = true;

  int get _studentId => widget.studentData['student_id'] is int
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
      final reports = await GuruEvaluasiService.getReports(
        studentId: _studentId,
      );
      if (mounted) {
        setState(() {
          _reports = reports;
          _isLoading = false;
          _selectedReportIndex = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat laporan: $e'),
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
                  : _reports.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.assignment_turned_in_outlined,
                                  size: 64, color: AppTheme.grey400),
                              const SizedBox(height: 16),
                              Text(
                                'Belum ada laporan evaluasi',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.grey400,
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadReports,
                          color: AppTheme.primaryGreen,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics(),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 16),
                            child: Column(
                              children: [
                                ..._reports.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final report = entry.value;
                                  return Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 16.0),
                                    child: _buildReportCard(report, index),
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
                    Icon(
                      Icons.assignment_turned_in_rounded,
                      size: 14,
                      color: AppTheme.softBlue,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Laporan Evaluasi',
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

  Widget _buildReportCard(GuruEvaluasiReport report, int index) {
    final isSelected = _selectedReportIndex == index;
    final formattedDate =
        "${report.evaluasiDate.day.toString().padLeft(2, '0')}-${report.evaluasiDate.month.toString().padLeft(2, '0')}-${report.evaluasiDate.year}";

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
            // ── Header: Title + Date ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.softBlue.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.assignment_turned_in_rounded,
                          color: AppTheme.softBlue,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              report.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.softBlue.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Bulan: ${report.bulan}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.softBlue,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    formattedDate,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.grey400,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Sections: A, B, C ──
            for (final kategori in evaluasiStruktur) ...[
              _buildKategoriSection(
                  kategori, report.nilaiData, report.keteranganData),
              if (kategori.kode != 'C') _buildDivider(),
            ],

            // ── Catatan ──
            if (report.catatan.isNotEmpty) ...[
              _buildDivider(),
              _buildLabelValue('Catatan', report.catatan),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildKategoriSection(
      EvaluasiKategori kategori,
      Map<String, String> nilaiData,
      Map<String, String> keteranganData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _kategoriColor(kategori.kode).withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${kategori.kode}. ${kategori.label}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: _kategoriColor(kategori.kode),
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Items
        ...kategori.items.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          final nilai = nilaiData[item.key] ?? '-';
          final keterangan = keteranganData[item.key] ?? '';
          return Padding(
            padding: EdgeInsets.only(
              bottom: idx < kategori.items.length - 1 ? 12 : 0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 20,
                      child: Text(
                        '${idx + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.grey400,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item.label,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    _buildNilaiBadge(nilai),
                  ],
                ),
                if (keterangan.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 20, top: 4, right: 8),
                    child: Text(
                      keterangan,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        fontStyle: FontStyle.italic,
                        color: AppTheme.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildNilaiBadge(String nilai) {
    Color bgColor;
    Color textColor;
    switch (nilai.toLowerCase()) {
      case 'sangat baik':
        bgColor = AppTheme.primaryGreen.withOpacity(0.12);
        textColor = AppTheme.primaryGreen;
        break;
      case 'baik':
        bgColor = AppTheme.softBlue.withOpacity(0.12);
        textColor = AppTheme.softBlue;
        break;
      case 'cukup':
        bgColor = AppTheme.gold.withOpacity(0.12);
        textColor = AppTheme.gold;
        break;
      case 'perlu perbaikan':
        bgColor = Colors.red.shade50;
        textColor = Colors.red.shade400;
        break;
      default:
        bgColor = AppTheme.grey100;
        textColor = AppTheme.grey400;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        nilai,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }

  Color _kategoriColor(String kode) {
    switch (kode) {
      case 'A':
        return AppTheme.softPurple;
      case 'B':
        return AppTheme.softBlue;
      case 'C':
        return AppTheme.primaryGreen;
      default:
        return AppTheme.grey400;
    }
  }

  Widget _buildLabelValue(String label, String value) {
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
          value.isNotEmpty ? value : '-',
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
      padding: const EdgeInsets.symmetric(vertical: 14),
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
                    final selectedReport = _reports[_selectedReportIndex!];
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GuruEvaluasiFormPage(
                          isEditing: true,
                          initialReport: selectedReport,
                          studentData: widget.studentData,
                        ),
                      ),
                    ).then((_) => _loadReports());
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GuruEvaluasiFormPage(
                          isEditing: false,
                          nextNumber: _reports.length + 1,
                          studentData: widget.studentData,
                        ),
                      ),
                    ).then((_) => _loadReports());
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
                        hasSelection
                            ? Icons.edit_document
                            : Icons.add_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        hasSelection
                            ? 'Edit Evaluasi'
                            : 'Tambah Evaluasi',
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
