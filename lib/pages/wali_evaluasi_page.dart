import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../services/evaluasi_view_service.dart';
import '../widgets/evaluasi_result_card.dart';
import '../widgets/skeleton_loader.dart';

class WaliEvaluasiPage extends StatefulWidget {
  const WaliEvaluasiPage({super.key});

  @override
  State<WaliEvaluasiPage> createState() => _WaliEvaluasiPageState();
}

class _WaliEvaluasiPageState extends State<WaliEvaluasiPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  List<EvaluasiViewReport> _reports = [];
  bool _isLoading = true;
  String? _errorMessage;

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
    _loadData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final reports = await EvaluasiViewService.getEvaluasiList();
      if (mounted) {
        setState(() {
          _reports = reports;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal memuat data: $e';
          _isLoading = false;
        });
      }
    }
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
              _buildHeader(),
              Expanded(
                child: _isLoading
                    ? _buildLoadingState()
                    : _errorMessage != null
                        ? _buildErrorState()
                        : _reports.isEmpty
                            ? _buildEmptyState()
                            : _buildContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
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
                      Icons.task_alt_rounded,
                      size: 14,
                      color: AppTheme.softBlue,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Wali Kelas',
                      style:
                          Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Evaluasi Anak',
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

  Widget _buildLoadingState() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: List.generate(
          3,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: SkeletonLoader(
              height: 200,
              width: double.infinity,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 48, color: AppTheme.grey400),
            const SizedBox(height: 14),
            Text(
              _errorMessage ?? 'Terjadi kesalahan',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba Lagi'),
              style:
                  TextButton.styleFrom(foregroundColor: AppTheme.primaryGreen),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_outlined, size: 64, color: AppTheme.grey200),
          const SizedBox(height: 16),
          Text(
            'Belum ada evaluasi',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.grey400,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Evaluasi dari wali kelas akan tampil di sini',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.grey400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    // Group reports by student name for wali with multiple children
    final hasMultipleStudents =
        _reports.map((r) => r.studentId).toSet().length > 1;

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppTheme.primaryGreen,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        itemCount: _reports.length + 1,
        itemBuilder: (context, index) {
          if (index == _reports.length) {
            return const SizedBox(height: 100);
          }
          final report = _reports[index];

          // Show student name divider when multiple students
          final showStudentHeader = hasMultipleStudents &&
              (index == 0 ||
                  _reports[index - 1].studentId != report.studentId);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showStudentHeader) ...[
                if (index > 0) const SizedBox(height: 12),
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: AppTheme.mainGradient,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: AppTheme.greenGlow,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person_rounded,
                          size: 16, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        report.studentName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      if (report.className.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            report.className,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: EvaluasiSummaryCard(
                  report: report,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    showEvaluasiBottomSheet(context, report);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
