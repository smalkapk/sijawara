import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme.dart';
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
                    ? _buildLoadingState()
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

  // ── Loading ──
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: AppTheme.primaryGreen,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Memuat data tahfidz...',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.grey400,
              fontWeight: FontWeight.w500,
            ),
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
          // ── Summary Card ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: _buildSetoranSummary(),
            ),
          ),

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
  Widget _buildSetoranSummary() {
    final totalSetoran = _setoranList.length;
    final sudahParaf = _setoranList.where((s) => s.guruName.isNotEmpty).length;
    final lastSetoran = _setoranList.isNotEmpty ? _setoranList.last : null;

    // Hitung nilai rata-rata
    String rataRata = '-';
    if (_setoranList.isNotEmpty) {
      final nilaiMap = {'A': 4.0, 'B+': 3.5, 'B': 3.0, 'C': 2.0, 'D': 1.0};
      final total = _setoranList.fold<double>(
          0, (sum, s) => sum + (nilaiMap[s.grade] ?? 0));
      final avg = total / _setoranList.length;
      if (avg >= 3.5) {
        rataRata = 'A';
      } else if (avg >= 2.5) {
        rataRata = 'B';
      } else if (avg >= 1.5) {
        rataRata = 'C';
      } else {
        rataRata = 'D';
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.mainGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.greenGlow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.menu_book_rounded,
                  color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              Text(
                'Setoran Al-Qur\'an',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Rata-rata: $rataRata',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              // Circular total setoran
              SizedBox(
                width: 80,
                height: 80,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        value: totalSetoran > 0
                            ? (sudahParaf / totalSetoran).clamp(0.0, 1.0)
                            : 0,
                        strokeWidth: 6,
                        strokeCap: StrokeCap.round,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        color: Colors.white,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$totalSetoran',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'setoran',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lastSetoran != null
                          ? 'Terakhir: ${lastSetoran.surahName}'
                          : 'Belum ada setoran',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lastSetoran != null
                          ? 'Ayat ${lastSetoran.ayatFrom} - ${lastSetoran.ayatTo}'
                          : 'Siswa belum memiliki setoran',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.8),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$sudahParaf/$totalSetoran sudah diparaf guru',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.7),
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

  // ── Stats Row (mini) ──
  Widget _buildSetoranStatsRow() {
    final countA = _setoranList.where((s) => s.grade == 'A').length;
    final countB =
        _setoranList.where((s) => s.grade == 'B' || s.grade == 'B+').length;
    final countC = _setoranList.where((s) => s.grade == 'C').length;
    final countD = _setoranList.where((s) => s.grade == 'D').length;

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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
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
    final dateFormat = DateFormat('EEEE, d MMMM yyyy', 'id_ID');
    final formattedDate = dateFormat.format(setoran.setoranAt);

    // Nilai badge color
    Color nilaiColor;
    switch (setoran.grade) {
      case 'A':
        nilaiColor = const Color(0xFF059669);
        break;
      case 'B+':
      case 'B':
        nilaiColor = AppTheme.softBlue;
        break;
      case 'C':
        nilaiColor = AppTheme.gold;
        break;
      case 'D':
        nilaiColor = const Color(0xFFEF4444);
        break;
      default:
        nilaiColor = AppTheme.grey400;
    }

    // Setoran range text
    final setoranRange =
        'QS. ${setoran.surahName}: ${setoran.ayatFrom} — ${setoran.ayatTo}';

    final sudahParaf = setoran.guruName.isNotEmpty;

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
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          boxShadow: AppTheme.softShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Date header strip ──
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: AppTheme.mainGradient,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  // Nomor urut
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      '$setoranNo',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(
                    Icons.calendar_today_rounded,
                    color: Colors.white70,
                    size: 13,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      formattedDate,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  // Nilai badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      setoran.grade,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: nilaiColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Content ──
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Setoran range
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.auto_stories_rounded,
                          size: 16,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Setoran',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.grey400,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              setoranRange,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  Container(height: 1, color: AppTheme.grey100),
                  const SizedBox(height: 12),

                  // Nilai & Paraf row
                  Row(
                    children: [
                      // Nilai
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: nilaiColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.grade_rounded,
                          size: 16,
                          color: nilaiColor,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nilai',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.grey400,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            _nilaiLabel(setoran.grade),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: nilaiColor,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Paraf guru
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: sudahParaf
                              ? AppTheme.primaryGreen.withValues(alpha: 0.08)
                              : AppTheme.gold.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          sudahParaf
                              ? Icons.verified_rounded
                              : Icons.pending_rounded,
                          size: 16,
                          color: sudahParaf
                              ? AppTheme.primaryGreen
                              : AppTheme.gold,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Paraf Guru',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.grey400,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            sudahParaf
                                ? (setoran.guruName.isNotEmpty
                                    ? setoran.guruName
                                    : 'Sudah')
                                : 'Menunggu',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: sudahParaf
                                  ? AppTheme.primaryGreen
                                  : AppTheme.gold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Notes section
                  if (setoran.notes.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(height: 1, color: AppTheme.grey100),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppTheme.teal.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.note_rounded,
                            size: 16,
                            color: AppTheme.teal,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Catatan',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.grey400,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                setoran.notes,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textPrimary,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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

  String _nilaiLabel(String nilai) {
    switch (nilai) {
      case 'A':
        return 'Mumtaz';
      case 'B+':
        return 'Jayyid Jiddan';
      case 'B':
        return 'Jayyid';
      case 'C':
        return 'Maqbul';
      case 'D':
        return 'Rasib';
      default:
        return nilai;
    }
  }
}
