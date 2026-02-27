import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/guru_evaluasi_service.dart';
import '../services/evaluasi_view_service.dart';

/// Card ringkas untuk daftar evaluasi (hanya judul, guru, bulan).
/// Tap untuk membuka detail di bottom sheet.
class EvaluasiSummaryCard extends StatelessWidget {
  final EvaluasiViewReport report;
  final VoidCallback? onTap;

  const EvaluasiSummaryCard({
    super.key,
    required this.report,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          boxShadow: AppTheme.softShadow,
          border: Border.all(color: AppTheme.grey100, width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.softBlue.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.assignment_turned_in_rounded,
                color: AppTheme.softBlue,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    report.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    report.bulan,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  if (report.guruName.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.person_outline_rounded,
                            size: 12, color: AppTheme.primaryGreen),
                        const SizedBox(width: 4),
                        Text(
                          report.guruName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.grey400,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget card yang menampilkan hasil evaluasi guru secara lengkap.
/// Digunakan di bottom-sheet live-timeline dan detail view.
class EvaluasiResultCard extends StatelessWidget {
  final EvaluasiViewReport report;

  const EvaluasiResultCard({
    super.key,
    required this.report,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.softShadow,
        border: Border.all(color: AppTheme.grey100, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header minimalis ──
          Row(
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
                    if (report.guruName.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.person_outline_rounded,
                              size: 13, color: AppTheme.primaryGreen),
                          const SizedBox(width: 4),
                          Text(
                            report.guruName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryGreen,
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
          const SizedBox(height: 20),

          // ── Sections: A, B, C ──
          for (final kategori in evaluasiStruktur) ...[
            _buildKategoriSection(kategori, report.nilaiData,
                report.keteranganData),
            if (kategori.kode != 'C') _buildDivider(),
          ],

          // ── Catatan ──
          if (report.catatan.isNotEmpty) ...[
            _buildDivider(),
            _buildLabelValue('Catatan', report.catatan),
          ],
        ],
      ),
    );
  }

  Widget _buildKategoriSection(
    EvaluasiKategori kategori,
    Map<String, String> nilaiData,
    Map<String, String> keteranganData,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                    padding:
                        const EdgeInsets.only(left: 20, top: 4, right: 8),
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
}

/// Bottom sheet yang menampilkan hasil evaluasi.
/// Digunakan dari wali_live_page dan fitur lainnya.
void showEvaluasiBottomSheet(
  BuildContext context,
  EvaluasiViewReport report,
) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      return DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (ctx, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: AppTheme.bgColor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.grey200,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: AppTheme.mainGradient,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.assignment_turned_in_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Hasil Evaluasi Guru',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            if (report.guruName.isNotEmpty)
                              Text(
                                'Oleh: ${report.guruName}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppTheme.grey100,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: AppTheme.grey400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                    child: EvaluasiResultCard(report: report),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
