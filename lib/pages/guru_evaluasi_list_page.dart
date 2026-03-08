import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../widgets/skeleton_loader.dart';
import '../services/tahfidz_service.dart';
import 'guru_evaluasi_report_page.dart';

class GuruEvaluasiListPage extends StatefulWidget {
  const GuruEvaluasiListPage({super.key});

  @override
  State<GuruEvaluasiListPage> createState() => _GuruEvaluasiListPageState();
}

class _GuruEvaluasiListPageState extends State<GuruEvaluasiListPage> {
  List<TahfidzStudent> _allStudents = [];
  List<TahfidzStudent> _filteredStudents = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoading = true);
    try {
      final students = await TahfidzService.getStudents();
      if (mounted) {
        setState(() {
          _allStudents = students;
          _filteredStudents = students;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat daftar siswa: $e'),
            backgroundColor: Colors.red.shade400,
          ),
        );
      }
    }
  }

  void _filterStudents(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      if (_searchQuery.isEmpty) {
        _filteredStudents = _allStudents;
      } else {
        _filteredStudents = _allStudents.where((s) {
          return s.name.toLowerCase().contains(_searchQuery) ||
              s.nis.toLowerCase().contains(_searchQuery);
        }).toList();
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
            _buildHeader(),
            _buildSearchFilter(),
            Expanded(
              child: _isLoading
                    ? ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        itemCount: 6,
                        itemBuilder: (context, index) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.white,
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusMd),
                              border:
                                  Border.all(color: AppTheme.grey100, width: 1),
                            ),
                            child: Row(
                              children: [
                                SkeletonLoader(
                                  height: 44,
                                  width: 44,
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SkeletonLoader(
                                          height: 16, width: double.infinity),
                                      const SizedBox(height: 8),
                                      SkeletonLoader(
                                        height: 12,
                                        width: 120,
                                        borderRadius:
                                            BorderRadius.circular(6),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SkeletonLoader(
                                  height: 24,
                                  width: 24,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ],
                            ),
                          );
                        },
                      )
                  : _filteredStudents.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.people_outline_rounded,
                                  size: 64, color: AppTheme.grey400),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'Siswa tidak ditemukan'
                                    : 'Belum ada siswa',
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
                          color: AppTheme.primaryGreen,
                          onRefresh: _loadStudents,
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics(),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 8),
                            itemCount: _filteredStudents.length,
                            itemBuilder: (context, index) {
                              return _buildStudentCard(
                                  _filteredStudents[index]);
                            },
                          ),
                        ),
            ),
          ],
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
                    const Icon(
                      Icons.assignment_turned_in_rounded,
                      size: 14,
                      color: AppTheme.softBlue,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Evaluasi',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Daftar Siswa',
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

  Widget _buildSearchFilter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48,
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
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, color: AppTheme.grey400, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: _filterStudents,
                      decoration: InputDecoration(
                        hintText: 'Cari nama/NIS siswa...',
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: AppTheme.grey400,
                          fontWeight: FontWeight.w500,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              gradient: AppTheme.mainGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppTheme.greenGlow,
            ),
            child: const Icon(Icons.filter_list_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentCard(TahfidzStudent student) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GuruEvaluasiReportPage(
              studentData: {
                'student_id': student.studentId,
                'name': student.name,
                'nis': student.nis,
                'class_name': student.className,
              },
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.grey100, width: 1),
        ),
        child: Row(
          children: [
            _buildStudentAvatar(student.avatarUrl, student.name, 44),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.grey400),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentAvatar(String? avatarUrl, String name, double size) {
    final url = avatarUrl ?? '';
    if (url.isNotEmpty) {
      final imageUrl = url.startsWith('http') ? url : 'https://portal-smalka.com/$url';
      return ClipOval(
        child: Image.network(
          imageUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: size, height: size,
              decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.softBlue.withOpacity(0.1)),
              child: const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.softBlue))),
            );
          },
          errorBuilder: (_, __, ___) => _buildInitials(name, size),
        ),
      );
    }
    return _buildInitials(name, size);
  }

  Widget _buildInitials(String name, double size) {
    final initials = name.isNotEmpty
        ? name.trim().split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase()
        : '?';
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.softBlue.withOpacity(0.1)),
      child: Center(
        child: Text(initials, style: TextStyle(fontSize: size * 0.4, fontWeight: FontWeight.w800, color: AppTheme.softBlue)),
      ),
    );
  }
}
