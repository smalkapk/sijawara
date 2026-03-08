import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme.dart';
import '../widgets/skeleton_loader.dart';
import '../services/tahfidz_service.dart';

class WaliTahfidzPage extends StatefulWidget {
  final int? studentId;
  const WaliTahfidzPage({super.key, this.studentId});

  @override
  State<WaliTahfidzPage> createState() => _WaliTahfidzPageState();
}

class _WaliTahfidzPageState extends State<WaliTahfidzPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  List<TahfidzSetoran> _setoranList = [];
  bool _isLoading = true;

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
    _loadSetoran();
  }

  Future<void> _loadSetoran() async {
    setState(() => _isLoading = true);
    try {
      final data = await TahfidzService.getWaliSetoran(
        studentId: widget.studentId,
      );
      if (!mounted) return;
      setState(() {
        _setoranList = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      debugPrint('Gagal load setoran: $e');
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
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
                    ? const PublicSpeakingSkeleton()
                    : _buildContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ──
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                          Icons.menu_book_rounded,
                          size: 14,
                          color: AppTheme.softPurple,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Laporan Setoran',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tahfidz Al-Qur\'an',
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
        ],
      ),
    );
  }

  // ── Content ──
  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: _loadSetoran,
      color: AppTheme.primaryGreen,
      backgroundColor: AppTheme.white,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          // ── Stats mini row ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: _buildSetoranStatsRow(),
            ),
          ),

          // ── Section Label ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 16,
                    decoration: BoxDecoration(
                      gradient: AppTheme.mainGradient,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Riwayat Setoran',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const Spacer(),
                  Text(
                    '${_setoranList.length} setoran',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.grey400,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Setoran List ──
          _setoranList.isEmpty
              ? SliverToBoxAdapter(child: _buildEmptySetoran())
              : SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final setoran =
                            _setoranList[_setoranList.length - 1 - index];
                        final setoranNo = _setoranList.length - index;
                        return _buildSetoranCard(setoran, index, setoranNo);
                      },
                      childCount: _setoranList.length,
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  // ── Setoran Summary Card ──
  // ── Stats Row (mini) ──
  Widget _buildSetoranStatsRow() {
    // Hitung dari grade per-surat, bukan per-setoran
    final allGrades = _setoranList.expand((s) =>
      s.isMultiSurah
        ? s.items.map((i) => i.grade)
        : [s.grade],
    );
    final countA = allGrades.where((g) => g == 'A').length;
    final countB = allGrades.where((g) => g == 'B' || g == 'B+').length;
    final countC = allGrades.where((g) => g == 'C').length;
    final countD = allGrades.where((g) => g == 'D').length;

    return Row(
      children: [
        Expanded(
          child: _buildMiniStat('A', '$countA', const Color(0xFF059669)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMiniStat('B', '$countB', AppTheme.softBlue),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMiniStat('C', '$countC', AppTheme.gold),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMiniStat('D', '$countD', const Color(0xFFEF4444)),
        ),
      ],
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.grey100, width: 1),
      ),
      child: Column(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Nilai $label',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: AppTheme.grey400,
            ),
          ),
        ],
      ),
    );
  }

  // ── Empty State ──
  Widget _buildEmptySetoran() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 100),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.menu_book_rounded,
              size: 56,
              color: AppTheme.primaryGreen.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Belum Ada Setoran',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Riwayat setoran tahfidz anak akan muncul di sini',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.grey400,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── Setoran Card ──
  Widget _buildSetoranCard(
      TahfidzSetoran setoran, int animIndex, int setoranNo) {
    final dateStr = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(setoran.setoranAt);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (animIndex * 60)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.grey100, width: 1),
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
                  if (setoran.isMultiSurah && setoran.items.isNotEmpty)
                    for (int i = 0; i < setoran.items.length; i++) ...[
                      if (i > 0) const SizedBox(height: 6),
                      _buildSetoranItemRow(
                        surahName: setoran.items[i].surahName,
                        ayatText: 'Ayat ${setoran.items[i].ayatFrom} - ${setoran.items[i].ayatTo}',
                        grade: setoran.items[i].grade,
                      ),
                    ]
                  else
                    _buildSetoranItemRow(
                      surahName: setoran.surahName,
                      ayatText: 'Ayat ${setoran.ayatFrom} - ${setoran.ayatTo}',
                      grade: setoran.grade,
                    ),
                  if (setoran.notes.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(height: 1, color: AppTheme.grey100),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Catatan Guru: ${setoran.notes}',
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
}
