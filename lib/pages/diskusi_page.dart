import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../services/diskusi_service.dart';
import '../widgets/ps_point_animation.dart';
import 'diskusi_form_page.dart';

class DiskusiPage extends StatefulWidget {
  const DiskusiPage({super.key});

  @override
  State<DiskusiPage> createState() => _DiskusiPageState();
}

class _DiskusiPageState extends State<DiskusiPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  List<DiskusiNote> _notes = [];
  bool _isLoading = true;
  int? _selectedNoteIndex;

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
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    setState(() => _isLoading = true);
    try {
      final notes = await DiskusiService.getNotes();
      if (!mounted) return;
      setState(() {
        _notes = notes;
        _isLoading = false;
        _selectedNoteIndex = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      debugPrint('Gagal load catatan: $e');
    }
  }

  void _openAddForm() async {
    final confirmed = await _showStayWarning();
    if (confirmed != true) return;

    if (!mounted) return;
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const DiskusiFormPage(),
      ),
    );
    if (result == 'new') {
      _loadNotes();
      if (mounted) {
        PSPointAnimationHelper.show(context: context, points: 2, onComplete: () {});
      }
    } else if (result == 'edit') {
      _loadNotes();
    }
  }

  Future<bool?> _showStayWarning() {
    HapticFeedback.mediumImpact();
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.grey200,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      size: 40,
                      color: Colors.orange.shade600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Perhatian',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Setelah masuk halaman catatan, kamu harus menyelesaikan dan menyimpan catatan sebelum keluar. Pastikan mentor sudah menandatangani sebelum menyimpan.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.grey600,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx, true),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: AppTheme.mainGradient,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMd),
                        boxShadow: AppTheme.greenGlow,
                      ),
                      child: const Center(
                        child: Text(
                          'Saya Mengerti, Lanjutkan',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _openEditForm(DiskusiNote note) async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => DiskusiFormPage(note: note),
      ),
    );
    if (result == 'edit' || result == 'new') {
      _loadNotes();
    }
  }

  void _deleteNote(DiskusiNote note) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        title: const Text('Hapus Catatan'),
        content: const Text('Yakin ingin menghapus catatan ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Batal',
              style: TextStyle(color: AppTheme.grey600),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Hapus',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DiskusiService.deleteNote(note.id);
      _loadNotes();
      if (mounted) {
        PSPointAnimationHelper.show(context: context, points: -2, onComplete: () {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Catatan berhasil dihapus'),
            backgroundColor: AppTheme.primaryGreen,
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
                    : _notes.isEmpty
                        ? _buildEmptyState()
                        : _buildNotesList(),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomActions(),
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
                        Icon(Icons.menu_book_rounded,
                            size: 14, color: AppTheme.softPurple),
                        const SizedBox(width: 6),
                        Text(
                          'Catatan Tugas',
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
                      'Diskusi Keislaman\ndan Kebangsaan',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            height: 1.2,
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

  // ── Bottom Actions ──
  Widget _buildBottomActions() {
    final hasSelection = _selectedNoteIndex != null;

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
                    final selectedNote = _notes[_selectedNoteIndex!];
                    _openEditForm(selectedNote);
                  } else {
                    _openAddForm();
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
                        hasSelection ? 'Edit Catatan' : 'Tambah Catatan',
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

  // ── Loading State ──
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
            'Memuat catatan...',
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

  // ── Empty State ──
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.menu_book_rounded,
                size: 56,
                color: AppTheme.primaryGreen.withOpacity(0.4),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Belum Ada Catatan',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tekan tombol di bawah untuk menambahkan\ncatatan diskusi baru',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.grey400,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Notes List ──
  Widget _buildNotesList() {
    return RefreshIndicator(
      onRefresh: _loadNotes,
      color: AppTheme.primaryGreen,
      backgroundColor: AppTheme.white,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
        itemCount: _notes.length,
        itemBuilder: (context, index) {
          return _buildNoteCard(_notes[index], index);
        },
      ),
    );
  }

  // ── Note Card ──
  Widget _buildNoteCard(DiskusiNote note, int index) {
    final isSelected = _selectedNoteIndex == index;
    final formattedDate =
        "${note.date.day.toString().padLeft(2, '0')}-${note.date.month.toString().padLeft(2, '0')}-${note.date.year}";

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 80)),
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
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() {
            if (_selectedNoteIndex == index) {
              _selectedNoteIndex = null;
            } else {
              _selectedNoteIndex = index;
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
              // Header row
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
                            color: AppTheme.softPurple.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.menu_book_rounded,
                            color: AppTheme.softPurple,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            note.judul.isNotEmpty
                                ? note.judul
                                : 'Tanpa Judul',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formattedDate,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.grey400,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _deleteNote(note);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.red.shade400,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Content items
              _buildReportItem(
                'Materi',
                note.materi.isNotEmpty ? note.materi : '(Belum diisi)',
              ),
              _buildCardDivider(),
              _buildReportItem(
                'Mentor',
                note.mentor.isNotEmpty
                    ? note.mentor
                    : '(Belum diisi)',
              ),
              if (note.note.isNotEmpty) ...[
                _buildCardDivider(),
                _buildReportItem('Catatan', note.note),
              ],
              // Signature section
              _buildCardDivider(),
              _buildSignatureItem(note),
            ],
          ),
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

  Widget _buildCardDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Container(
        height: 1,
        color: AppTheme.grey100,
      ),
    );
  }

  Widget _buildSignatureItem(DiskusiNote note) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Tanda Tangan Mentor',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.grey400,
                letterSpacing: 0.5,
              ),
            ),
            const Spacer(),
            if (note.signatureBase64.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Wajib',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Sudah TTD',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (note.signatureBase64.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 60,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppTheme.grey200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Image.memory(
                base64Decode(note.signatureBase64),
                fit: BoxFit.contain,
              ),
            ),
          )
        else
          Text(
            '(Belum ditandatangani)',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.grey400,
            ),
          ),
      ],
    );
  }
}
