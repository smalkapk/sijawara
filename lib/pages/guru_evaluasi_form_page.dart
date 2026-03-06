import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../services/guru_evaluasi_service.dart';

class GuruEvaluasiFormPage extends StatefulWidget {
  final bool isEditing;
  final GuruEvaluasiReport? initialReport;
  final int nextNumber;
  final Map<String, dynamic> studentData;

  const GuruEvaluasiFormPage({
    super.key,
    this.isEditing = false,
    this.initialReport,
    this.nextNumber = 1,
    required this.studentData,
  });

  @override
  State<GuruEvaluasiFormPage> createState() => _GuruEvaluasiFormPageState();
}

class _GuruEvaluasiFormPageState extends State<GuruEvaluasiFormPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Bulan & tahun
  late int _selectedBulanIndex; // 0-11
  late int _selectedTahun;

  // Nilai per item (key → nilaiOption)
  final Map<String, String> _nilaiValues = {};

  // Keterangan per item (key → teks deskripsi)
  final Map<String, TextEditingController> _keteranganControllers = {};

  final _catatanController = TextEditingController();
  bool _isSaving = false;

  // Cache rekomendasi dari DB
  final Map<String, String> _rekomendasiCache = {};
  final Map<String, bool> _rekomendasiLoading = {};

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

    final now = DateTime.now();
    _selectedBulanIndex = now.month - 1;
    _selectedTahun = now.year;

    // Inisialisasi semua item
    for (final kategori in evaluasiStruktur) {
      for (final item in kategori.items) {
        _nilaiValues[item.key] = '';
        _keteranganControllers[item.key] = TextEditingController();
      }
    }

    // Pre-fill saat editing
    if (widget.isEditing && widget.initialReport != null) {
      final r = widget.initialReport!;
      _parseBulan(r.bulan);
      for (final entry in r.nilaiData.entries) {
        _nilaiValues[entry.key] = entry.value;
      }
      for (final entry in r.keteranganData.entries) {
        _keteranganControllers[entry.key]?.text = entry.value;
      }
      _catatanController.text = r.catatan;
    }

    // Muat rekomendasi untuk item-item khusus
    _loadRekomendasi();
  }

  void _parseBulan(String bulan) {
    final parts = bulan.split(' ');
    if (parts.length == 2) {
      final idx = bulanNames
          .indexWhere((b) => b.toLowerCase() == parts[0].toLowerCase());
      if (idx >= 0) _selectedBulanIndex = idx;
      final tahun = int.tryParse(parts[1]);
      if (tahun != null) _selectedTahun = tahun;
    }
  }

  /// Format bulan menjadi YYYY-MM untuk query ke API
  String get _monthQuery {
    final month = (_selectedBulanIndex + 1).toString().padLeft(2, '0');
    return '$_selectedTahun-$month';
  }

  int get _studentId => widget.studentData['student_id'] is int
      ? widget.studentData['student_id']
      : int.parse(widget.studentData['student_id'].toString());

  /// Memuat rekomendasi nilai dari database untuk item khusus
  Future<void> _loadRekomendasi() async {
    final specialItems = <EvaluasiItem>[];
    for (final k in evaluasiStruktur) {
      for (final item in k.items) {
        if (item.riwayatType != RiwayatType.none) {
          specialItems.add(item);
        }
      }
    }

    for (final item in specialItems) {
      setState(() => _rekomendasiLoading[item.key] = true);
    }

    try {
      final riwayatTugas = await GuruEvaluasiService.getRiwayat(
        studentId: _studentId,
        type: RiwayatType.tugas,
        month: _monthQuery,
      );
      final riwayatTahfidz = await GuruEvaluasiService.getRiwayat(
        studentId: _studentId,
        type: RiwayatType.tahfidz,
        month: _monthQuery,
      );
      final riwayatIbadah = await GuruEvaluasiService.getRiwayat(
        studentId: _studentId,
        type: RiwayatType.ibadah,
        month: _monthQuery,
      );

      if (mounted) {
        setState(() {
          _rekomendasiCache['tugas'] =
              _hitungRekomendasi(riwayatTugas, 'tugas');
          _rekomendasiCache['tahfidz_hafalan_doa'] =
              _hitungRekomendasi(riwayatTahfidz, 'tahfidz');
          _rekomendasiCache['sholat_wajib'] =
              _hitungRekomendasiIbadah(riwayatIbadah, 'sholat_wajib');
          _rekomendasiCache['sholat_sunnah'] =
              _hitungRekomendasiIbadah(riwayatIbadah, 'sholat_sunnah');
          _rekomendasiCache['puasa'] =
              _hitungRekomendasiIbadah(riwayatIbadah, 'puasa');

          for (final item in specialItems) {
            _rekomendasiLoading[item.key] = false;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          for (final item in specialItems) {
            _rekomendasiLoading[item.key] = false;
          }
        });
      }
      debugPrint('Gagal memuat rekomendasi: $e');
    }
  }

  /// Hitung rekomendasi dari data riwayat tugas/tahfidz
  String _hitungRekomendasi(List<RiwayatItem> data, String type) {
    if (data.isEmpty) return '-';

    // Untuk tugas: rekomendasi berdasarkan jumlah aktivitas
    if (type == 'tugas') {
      final count = data.length;
      if (count >= 4) return 'Sangat Baik';
      if (count >= 3) return 'Baik';
      if (count >= 2) return 'Cukup';
      return 'Perlu Perbaikan';
    }

    // Untuk tahfidz & ibadah: rekomendasi berdasarkan badge kualitas
    int totalScore = 0;
    int countWithBadge = 0;
    for (final item in data) {
      final badge = (item.badge ?? '').toLowerCase();
      if (badge.contains('sangat baik')) {
        totalScore += 4;
        countWithBadge++;
      } else if (badge.contains('baik')) {
        totalScore += 3;
        countWithBadge++;
      } else if (badge.contains('cukup')) {
        totalScore += 2;
        countWithBadge++;
      } else if (badge.contains('perlu perbaikan')) {
        totalScore += 1;
        countWithBadge++;
      }
    }

    if (countWithBadge == 0) return '-';
    final avg = totalScore / countWithBadge;
    if (avg >= 3.5) return 'Sangat Baik';
    if (avg >= 2.5) return 'Baik';
    if (avg >= 1.5) return 'Cukup';
    return 'Perlu Perbaikan';
  }

  /// Hitung rekomendasi ibadah berdasarkan badge/subtitle
  String _hitungRekomendasiIbadah(List<RiwayatItem> data, String subType) {
    if (data.isEmpty) return '-';
    // Filter berdasarkan subtype jika ada di title
    final filtered = data.where((d) {
      final t = d.title.toLowerCase();
      if (subType == 'sholat_wajib') return t.contains('wajib');
      if (subType == 'sholat_sunnah') return t.contains('sunnah');
      if (subType == 'puasa') return t.contains('puasa');
      return true;
    }).toList();
    if (filtered.isEmpty) return _hitungRekomendasi(data, subType);
    return _hitungRekomendasi(filtered, subType);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _catatanController.dispose();
    for (final c in _keteranganControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String get _bulanLabel =>
      '${bulanNames[_selectedBulanIndex]} $_selectedTahun';

  int get _evaluasiNumber => widget.isEditing
      ? widget.initialReport!.evaluasiNumber
      : widget.nextNumber;

  String get _titleLabel =>
      'Laporan Evaluasi ${ordinalLabel(_evaluasiNumber)}';

  void _saveForm() async {
    HapticFeedback.mediumImpact();

    // Validasi: minimal 1 item terisi
    final filledCount =
        _nilaiValues.values.where((v) => v.isNotEmpty).length;
    if (filledCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Harap isi minimal satu item evaluasi'),
          backgroundColor: Colors.red.shade400,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Hanya kirim item yang terisi
      final cleanNilai = Map<String, String>.from(_nilaiValues)
        ..removeWhere((_, v) => v.isEmpty);

      // Keterangan hanya untuk item yang punya nilai
      final cleanKeterangan = <String, String>{};
      for (final key in cleanNilai.keys) {
        final text = _keteranganControllers[key]?.text.trim() ?? '';
        if (text.isNotEmpty) {
          cleanKeterangan[key] = text;
        }
      }

      final report = GuruEvaluasiReport(
        id: widget.isEditing ? widget.initialReport!.id : '',
        evaluasiNumber: _evaluasiNumber,
        bulan: _bulanLabel,
        nilaiData: cleanNilai,
        keteranganData: cleanKeterangan,
        catatan: _catatanController.text,
        evaluasiDate: DateTime.now(),
      );

      if (widget.isEditing) {
        await GuruEvaluasiService.updateReport(
          studentId: _studentId,
          report: report,
        );
      } else {
        await GuruEvaluasiService.addReport(
          studentId: _studentId,
          report: report,
        );
      }

      if (mounted) {
        setState(() => _isSaving = false);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isEditing
                ? 'Evaluasi berhasil diperbarui'
                : 'Evaluasi berhasil disimpan'),
            backgroundColor: AppTheme.primaryGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan evaluasi: $e'),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
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
              _buildHeader(context),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Info: Judul otomatis ──
                      _buildInfoCard(),
                      const SizedBox(height: 16),

                      // ── Pilih Bulan ──
                      _buildBulanPicker(),
                      const SizedBox(height: 24),

                      // ── Sections A, B, C ──
                      for (final kategori in evaluasiStruktur) ...[
                        _buildKategoriForm(kategori),
                        const SizedBox(height: 20),
                      ],

                      // ── Catatan ──
                      _buildCatatanField(),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomActions(context),
    );
  }

  // ═══════════════════════════════════════
  // Header
  // ═══════════════════════════════════════

  Widget _buildHeader(BuildContext context) {
    final title = widget.isEditing ? 'Edit Evaluasi' : 'Input Evaluasi';

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
                    Expanded(
                      child: Text(
                        widget.studentData['name'],
                        style:
                            Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  title,
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

  // ═══════════════════════════════════════
  // Info Card & Bulan Picker
  // ═══════════════════════════════════════

  Widget _buildInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.softBlue.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.softBlue.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded,
              size: 20, color: AppTheme.softBlue),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _titleLabel,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.softBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulanPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.calendar_month_rounded,
                size: 16, color: AppTheme.primaryGreen),
            const SizedBox(width: 8),
            const Text(
              'Bulan Evaluasi',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            // Bulan dropdown
            Expanded(
              flex: 3,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: AppTheme.grey100, width: 1),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _selectedBulanIndex,
                    isExpanded: true,
                    icon: Icon(Icons.keyboard_arrow_down_rounded,
                        color: AppTheme.grey400),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                    items: List.generate(12, (i) {
                      return DropdownMenuItem(
                        value: i,
                        child: Text(bulanNames[i]),
                      );
                    }),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _selectedBulanIndex = v);
                        _loadRekomendasi();
                      }
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Tahun dropdown
            Expanded(
              flex: 2,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: AppTheme.grey100, width: 1),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _selectedTahun,
                    isExpanded: true,
                    icon: Icon(Icons.keyboard_arrow_down_rounded,
                        color: AppTheme.grey400),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                    items: List.generate(11, (i) {
                      final year = 2024 + i;
                      return DropdownMenuItem(
                        value: year,
                        child: Text('$year'),
                      );
                    }),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _selectedTahun = v);
                        _loadRekomendasi();
                      }
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ═══════════════════════════════════════
  // Kategori & Item Form
  // ═══════════════════════════════════════

  Widget _buildKategoriForm(EvaluasiKategori kategori) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.grey100, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _kategoriColor(kategori.kode).withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _kategoriIcon(kategori.kode),
                  size: 16,
                  color: _kategoriColor(kategori.kode),
                ),
                const SizedBox(width: 8),
                Text(
                  '${kategori.kode}. ${kategori.label}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _kategoriColor(kategori.kode),
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Items
          ...kategori.items.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            return Padding(
              padding: EdgeInsets.only(
                bottom: idx < kategori.items.length - 1 ? 16 : 0,
              ),
              child: _buildNilaiItem(idx + 1, item),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildNilaiItem(int nomor, EvaluasiItem item) {
    final selectedValue = _nilaiValues[item.key] ?? '';
    final hasRekomendasi = item.riwayatType != RiwayatType.none;
    final rekomendasi = _rekomendasiCache[item.key];
    final isLoadingRek = _rekomendasiLoading[item.key] ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$nomor. ${item.label}',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 6),

        // ── Dropdown nilai ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          decoration: BoxDecoration(
            color: AppTheme.bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.grey100),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedValue.isEmpty ? null : selectedValue,
              isExpanded: true,
              hint: Text(
                'Pilih nilai...',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.grey400,
                  fontWeight: FontWeight.w500,
                ),
              ),
              icon: Icon(Icons.keyboard_arrow_down_rounded,
                  color: AppTheme.grey400, size: 20),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
              items: nilaiOptions.map((option) {
                return DropdownMenuItem(
                  value: option,
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _nilaiColor(option),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(option),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    _nilaiValues[item.key] = v;
                    // Auto-fill teks template
                    _keteranganControllers[item.key]?.text =
                        generateTemplateText(item, v);
                  });
                }
              },
            ),
          ),
        ),

        // ── Rekomendasi dari DB (hanya item khusus) ──
        if (hasRekomendasi) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.gold.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.gold.withOpacity(0.15)),
            ),
            child: isLoadingRek
                ? Row(
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.gold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Memuat rekomendasi...',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.gold,
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textSecondary,
                            height: 1.4,
                          ),
                          children: [
                            const TextSpan(
                              text: 'ALKA merekomendasikan nilai ',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            TextSpan(
                              text: rekomendasi ?? '-',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: _nilaiColor(rekomendasi ?? ''),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () => _showRiwayatBottomSheet(item),
                        child: Row(
                          children: [
                            Icon(
                              Icons.history_rounded,
                              size: 14,
                              color: AppTheme.softBlue,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Lihat riwayat ${riwayatLabel(item.riwayatType).toLowerCase()} siswa',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.softBlue,
                                decoration: TextDecoration.underline,
                                decorationColor: AppTheme.softBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],

        // ── Teks keterangan (muncul setelah nilai dipilih) ──
        if (selectedValue.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.grey100),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: TextField(
              controller: _keteranganControllers[item.key],
              maxLines: 3,
              minLines: 2,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
                height: 1.5,
              ),
              decoration: InputDecoration(
                hintText: 'Teks keterangan evaluasi...',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: AppTheme.grey400,
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ═══════════════════════════════════════
  // Bottom Sheet: Riwayat Data
  // ═══════════════════════════════════════

  void _showRiwayatBottomSheet(EvaluasiItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _RiwayatBottomSheet(
        studentId: _studentId,
        studentName: widget.studentData['name'] ?? '',
        item: item,
        initialMonth: _monthQuery,
      ),
    );
  }

  // ═══════════════════════════════════════
  // Catatan & Bottom Actions
  // ═══════════════════════════════════════

  Widget _buildCatatanField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.notes_rounded, size: 16, color: AppTheme.primaryGreen),
            const SizedBox(width: 8),
            const Text(
              'Catatan Tambahan',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.grey100, width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextField(
            controller: _catatanController,
            maxLines: 4,
            minLines: 3,
            decoration: InputDecoration(
              hintText: 'Tulis catatan tambahan...',
              hintStyle: TextStyle(
                fontSize: 14,
                color: AppTheme.grey400,
                fontWeight: FontWeight.w500,
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActions(BuildContext context) {
    return Container(
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
        child: GestureDetector(
          onTap: _isSaving ? null : _saveForm,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: _isSaving ? null : AppTheme.mainGradient,
              color: _isSaving ? AppTheme.grey200 : null,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              boxShadow: _isSaving ? [] : AppTheme.greenGlow,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isSaving)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                else
                  const Icon(
                    Icons.save_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                const SizedBox(width: 8),
                Text(
                  _isSaving ? 'Menyimpan...' : 'Simpan Evaluasi',
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
    );
  }

  // ═══════════════════════════════════════
  // Helper
  // ═══════════════════════════════════════

  Color _nilaiColor(String nilai) {
    switch (nilai.toLowerCase()) {
      case 'sangat baik':
        return AppTheme.primaryGreen;
      case 'baik':
        return AppTheme.softBlue;
      case 'cukup':
        return AppTheme.gold;
      case 'perlu perbaikan':
        return Colors.red.shade400;
      default:
        return AppTheme.grey400;
    }
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

  IconData _kategoriIcon(String kode) {
    switch (kode) {
      case 'A':
        return Icons.psychology_rounded;
      case 'B':
        return Icons.school_rounded;
      case 'C':
        return Icons.mosque_rounded;
      default:
        return Icons.category_rounded;
    }
  }
}

// ═════════════════════════════════════════════════════════
// Bottom Sheet: Riwayat data siswa dari bulan evaluasi
// ═════════════════════════════════════════════════════════

class _RiwayatBottomSheet extends StatefulWidget {
  final int studentId;
  final String studentName;
  final EvaluasiItem item;
  final String initialMonth; // YYYY-MM

  const _RiwayatBottomSheet({
    required this.studentId,
    required this.studentName,
    required this.item,
    required this.initialMonth,
  });

  @override
  State<_RiwayatBottomSheet> createState() => _RiwayatBottomSheetState();
}

class _RiwayatBottomSheetState extends State<_RiwayatBottomSheet> {
  late int _year;
  late int _month; // 1-12
  List<RiwayatItem> _data = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final parts = widget.initialMonth.split('-');
    _year = int.parse(parts[0]);
    _month = int.parse(parts[1]);
    _fetchData();
  }

  String get _monthQuery =>
      '$_year-${_month.toString().padLeft(2, '0')}';

  String get _monthLabel =>
      '${bulanNames[_month - 1]} $_year';

  void _prevMonth() {
    setState(() {
      _month--;
      if (_month < 1) {
        _month = 12;
        _year--;
      }
    });
    _fetchData();
  }

  void _nextMonth() {
    setState(() {
      _month++;
      if (_month > 12) {
        _month = 1;
        _year++;
      }
    });
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final data = await GuruEvaluasiService.getRiwayat(
        studentId: widget.studentId,
        type: widget.item.riwayatType,
        month: _monthQuery,
      );
      if (mounted) {
        setState(() {
          _data = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _data = [];
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.75;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.grey200,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.history_rounded,
                        size: 20, color: AppTheme.softBlue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Riwayat ${riwayatLabel(widget.item.riwayatType)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Icon(Icons.close_rounded,
                          size: 22, color: AppTheme.grey400),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  widget.studentName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Month navigator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.bgColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: _prevMonth,
                    icon: const Icon(Icons.chevron_left_rounded, size: 22),
                    color: AppTheme.primaryGreen,
                    splashRadius: 20,
                  ),
                  Text(
                    _monthLabel,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  IconButton(
                    onPressed: _nextMonth,
                    icon: const Icon(Icons.chevron_right_rounded, size: 22),
                    color: AppTheme.primaryGreen,
                    splashRadius: 20,
                  ),
                ],
              ),
            ),
          ),

          const Divider(height: 1, color: AppTheme.grey100),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppTheme.primaryGreen),
                  )
                : _data.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox_rounded,
                                size: 48, color: AppTheme.grey200),
                            const SizedBox(height: 12),
                            Text(
                              'Belum ada data di bulan ini',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.grey400,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(24),
                        itemCount: _data.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (_, index) {
                          return _buildRiwayatTile(_data[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiwayatTile(RiwayatItem item) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.grey100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.softBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _riwayatIcon(widget.item.riwayatType),
              size: 18,
              color: AppTheme.softBlue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (item.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  item.date,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.grey400,
                  ),
                ),
              ],
            ),
          ),
          if (item.badge != null) ...[
            const SizedBox(width: 8),
            _buildBadge(item.badge!),
          ],
        ],
      ),
    );
  }

  Widget _buildBadge(String badge) {
    Color bgColor;
    Color textColor;
    final lower = badge.toLowerCase();
    if (lower.contains('sangat baik') || lower == 'a') {
      bgColor = AppTheme.primaryGreen.withOpacity(0.12);
      textColor = AppTheme.primaryGreen;
    } else if (lower.contains('baik') || lower == 'b') {
      bgColor = AppTheme.softBlue.withOpacity(0.12);
      textColor = AppTheme.softBlue;
    } else if (lower.contains('cukup') || lower == 'c') {
      bgColor = AppTheme.gold.withOpacity(0.12);
      textColor = AppTheme.gold;
    } else if (lower.contains('hadir') || lower.contains('ya')) {
      bgColor = AppTheme.primaryGreen.withOpacity(0.12);
      textColor = AppTheme.primaryGreen;
    } else if (lower.contains('tidak') || lower.contains('alfa')) {
      bgColor = Colors.red.shade50;
      textColor = Colors.red.shade400;
    } else {
      bgColor = AppTheme.grey100;
      textColor = AppTheme.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        badge,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }

  IconData _riwayatIcon(RiwayatType type) {
    switch (type) {
      case RiwayatType.tugas:
        return Icons.assignment_rounded;
      case RiwayatType.tahfidz:
        return Icons.menu_book_rounded;
      case RiwayatType.ibadah:
        return Icons.mosque_rounded;
      default:
        return Icons.article_rounded;
    }
  }
}
