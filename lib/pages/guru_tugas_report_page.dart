import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../widgets/skeleton_loader.dart';
import '../services/guru_tugas_service.dart';

import 'guru_tugas_form_page.dart';

class GuruTugasReportPage extends StatefulWidget {
  final Map<String, dynamic> studentData;
  final String subjectName;

  const GuruTugasReportPage(
      {super.key, required this.studentData, required this.subjectName});

  @override
  State<GuruTugasReportPage> createState() => _GuruTugasReportPageState();
}

class _GuruTugasReportPageState extends State<GuruTugasReportPage> {
  int? _selectedReportIndex;
  List<GuruTugasReport> _reports = [];
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
      final reports = await GuruTugasService.getReports(
        studentId: _studentId,
        subject: widget.subjectName,
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
                    ? const PublicSpeakingSkeleton()
                  : _reports.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.assignment_outlined,
                                  size: 64, color: AppTheme.grey400),
                              const SizedBox(height: 16),
                              Text(
                                'Belum ada laporan tugas',
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
                    Icon(
                      Icons.history_edu_rounded,
                      size: 14,
                      color: AppTheme.softPurple,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Laporan Tugas',
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

  Widget _buildReportCard(GuruTugasReport report, int index) {
    final isSelected = _selectedReportIndex == index;
    final formattedDate =
        "${report.date.day.toString().padLeft(2, '0')}-${report.date.month.toString().padLeft(2, '0')}-${report.date.year}";

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
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryGreen.withOpacity(0.05)
              : AppTheme.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(
            color: AppTheme.grey100,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.judul.isNotEmpty ? report.judul : 'Tanpa Judul',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formattedDate,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.grey400,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildReportItem('Materi', report.materi),
            _buildDivider(),
            _buildReportItem('Mentor', report.mentor),
            if (report.note.isNotEmpty) ...[
              _buildDivider(),
              _buildReportItem('Catatan Guru', report.note),
            ],
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
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
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
        border: Border(
          top: BorderSide(color: AppTheme.grey100, width: 1),
        ),
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
                        builder: (_) => GuruTugasFormPage(
                          isEditing: true,
                          initialData: {
                            'id': selectedReport.id,
                            'date': selectedReport.date.toIso8601String().substring(0, 10),
                            'judul': selectedReport.judul,
                            'materi': selectedReport.materi,
                            'mentor': selectedReport.mentor,
                            'note': selectedReport.note,
                          },
                          subjectName: widget.subjectName,
                          studentData: widget.studentData,
                        ),
                      ),
                    ).then((_) => _loadReports());
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GuruTugasFormPage(
                          isEditing: false,
                          subjectName: widget.subjectName,
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
                    border: hasSelection
                        ? null
                        : Border.all(
                            color: AppTheme.grey100,
                            width: 1,
                          ),
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
                        hasSelection ? 'Edit Tugas' : 'Tambah Tugas',
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
