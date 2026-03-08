import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../services/diskusi_service.dart';
import '../widgets/skeleton_loader.dart';

class WaliDiskusiPage extends StatefulWidget {
  final int? studentId;
  const WaliDiskusiPage({super.key, this.studentId});

  @override
  State<WaliDiskusiPage> createState() => _WaliDiskusiPageState();
}

class _WaliDiskusiPageState extends State<WaliDiskusiPage> {
  List<DiskusiNote> _notes = [];
  bool _isLoading = true;
  int? _expandedNoteIndex;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    setState(() => _isLoading = true);
    try {
      final notes = await DiskusiService.getNotes(studentId: widget.studentId);
      if (!mounted) return;
      setState(() {
        _notes = notes;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      debugPrint('Gagal load catatan: $e');
    }
  }

  String _formatDateGroup(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final noteDate = DateTime(dt.year, dt.month, dt.day);

    if (noteDate == today) return 'Hari ini';
    if (noteDate == today.subtract(const Duration(days: 1))) return 'Kemarin';
    return DateFormat('d MMMM yyyy', 'id_ID').format(dt);
  }

  bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
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
    );
  }

  // ── App Bar (guru_chat_page style) ──
  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 16, 10),
      decoration: BoxDecoration(
        color: AppTheme.white,
        border: Border(bottom: BorderSide(color: AppTheme.grey100, width: 1)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
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
                child: const Icon(Icons.arrow_back_rounded,
                    color: AppTheme.primaryGreen, size: 20),
              ),
            ),
          ),
          const SizedBox(width: 14),
          CircleAvatar(
            radius: 20,
            backgroundColor: AppTheme.softPurple.withValues(alpha: 0.12),
            child: const Icon(Icons.menu_book_rounded,
                color: AppTheme.softPurple, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Diskusi Keislaman',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${_notes.length} catatan tugas',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.grey400,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: AppTheme.textSecondary),
            onPressed: _loadNotes,
          ),
        ],
      ),
    );
  }

  // ── Loading State (chat-style skeleton) ──
  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.grey100, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SkeletonLoader(
                      height: 32,
                      width: 32,
                      borderRadius: BorderRadius.circular(8)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonLoader(
                            height: 14,
                            width: MediaQuery.of(context).size.width * 0.5,
                            borderRadius: BorderRadius.circular(6)),
                        const SizedBox(height: 6),
                        SkeletonLoader(
                            height: 10,
                            width: 80,
                            borderRadius: BorderRadius.circular(6)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SkeletonLoader(
                  height: 12,
                  width: MediaQuery.of(context).size.width * 0.7,
                  borderRadius: BorderRadius.circular(6)),
              const SizedBox(height: 8),
              SkeletonLoader(
                  height: 12,
                  width: MediaQuery.of(context).size.width * 0.4,
                  borderRadius: BorderRadius.circular(6)),
            ],
          ),
        );
      },
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
                color: AppTheme.primaryGreen.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.menu_book_rounded,
                  size: 56,
                  color: AppTheme.primaryGreen.withValues(alpha: 0.4)),
            ),
            const SizedBox(height: 24),
            Text(
              'Belum Ada Laporan',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Siswa belum memiliki catatan\ntugas diskusi baru',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14, color: AppTheme.grey400, height: 1.5),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: _loadNotes,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  gradient: AppTheme.mainGradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: AppTheme.greenGlow,
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text('Muat Ulang',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Date Chip (chat-style) ──
  Widget _buildDateChip(String date) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.white,
        border: Border.all(color: AppTheme.grey100, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(date,
          style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600)),
    );
  }

  // ── Notes List (chat-area style) ──
  Widget _buildNotesList() {
    return RefreshIndicator(
      onRefresh: _loadNotes,
      color: AppTheme.primaryGreen,
      backgroundColor: AppTheme.white,
      child: Container(
        color: AppTheme.offWhite,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          itemCount: _notes.length,
          itemBuilder: (context, index) {
            final note = _notes[index];
            final showDate = index == 0 ||
                !_isSameDate(_notes[index - 1].date, note.date);
            return Column(
              children: [
                if (showDate)
                  _buildDateChip(_formatDateGroup(note.date)),
                _buildNoteCard(note, index),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Note Card (chat-bubble inspired) ──
  Widget _buildNoteCard(DiskusiNote note, int index) {
    final formattedTime = DateFormat('HH:mm').format(note.date);
    final isExpanded = _expandedNoteIndex == index;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 250 + (index * 40)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - value)),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() {
            _expandedNoteIndex = isExpanded ? null : index;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isExpanded
                ? AppTheme.primaryGreen.withValues(alpha: 0.03)
                : AppTheme.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isExpanded
                  ? AppTheme.primaryGreen.withValues(alpha: 0.15)
                  : AppTheme.grey100,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header section ──
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Mentor avatar
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: note.mentor.isNotEmpty
                          ? AppTheme.softPurple.withValues(alpha: 0.12)
                          : AppTheme.gold.withValues(alpha: 0.12),
                      child: Text(
                        note.mentor.isNotEmpty
                            ? _getInitials(note.mentor)
                            : '?',
                        style: TextStyle(
                          color: note.mentor.isNotEmpty
                              ? AppTheme.softPurple
                              : AppTheme.gold,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  note.mentor.isNotEmpty
                                      ? note.mentor
                                      : 'Menunggu Mentor',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: note.mentor.isNotEmpty
                                        ? AppTheme.textPrimary
                                        : AppTheme.gold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                formattedTime,
                                style: const TextStyle(
                                  color: AppTheme.grey400,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            note.judul.isNotEmpty ? note.judul : 'Tanpa Judul',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Materi preview ──
              Padding(
                padding: const EdgeInsets.fromLTRB(56, 4, 14, 0),
                child: Text(
                  note.materi.isNotEmpty ? note.materi : '(Belum ada materi)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: note.materi.isNotEmpty
                        ? AppTheme.textSecondary
                        : AppTheme.grey400,
                    height: 1.4,
                  ),
                  maxLines: isExpanded ? 10 : 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // ── Status badges ──
              Padding(
                padding: const EdgeInsets.fromLTRB(56, 8, 14, 12),
                child: Row(
                  children: [
                    _buildStatusBadge(
                      icon: Icons.subject_rounded,
                      label: 'Materi',
                      filled: note.materi.isNotEmpty,
                      color: AppTheme.primaryGreen,
                    ),
                    const SizedBox(width: 6),
                    _buildStatusBadge(
                      icon: Icons.draw_rounded,
                      label: 'TTD',
                      filled: note.signatureBase64.isNotEmpty,
                      color: AppTheme.softBlue,
                    ),
                    if (note.note.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      _buildStatusBadge(
                        icon: Icons.note_rounded,
                        label: 'Catatan',
                        filled: true,
                        color: AppTheme.teal,
                      ),
                    ],
                    const Spacer(),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.expand_more_rounded,
                        size: 20,
                        color: AppTheme.grey400,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Expanded detail ──
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: _buildExpandedDetail(note),
                crossFadeState: isExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 250),
                sizeCurve: Curves.easeOutCubic,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Expanded detail section ──
  Widget _buildExpandedDetail(DiskusiNote note) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 1, color: AppTheme.grey100),
          const SizedBox(height: 14),

          // Materi detail
          _buildDetailRow(
            icon: Icons.subject_rounded,
            iconColor: AppTheme.primaryGreen,
            label: 'Materi',
            value: note.materi.isNotEmpty ? note.materi : '(Belum diisi)',
            isEmpty: note.materi.isEmpty,
          ),

          const SizedBox(height: 14),

          // Mentor detail
          _buildDetailRow(
            icon: Icons.person_rounded,
            iconColor: AppTheme.softPurple,
            label: 'Mentor',
            value: note.mentor.isNotEmpty ? note.mentor : '(Belum diisi)',
            isEmpty: note.mentor.isEmpty,
            trailing: note.mentor.isEmpty
                ? Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.gold.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Menunggu',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.gold,
                      ),
                    ),
                  )
                : null,
          ),

          // Catatan
          if (note.note.isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildDetailRow(
              icon: Icons.note_rounded,
              iconColor: AppTheme.teal,
              label: 'Catatan',
              value: note.note,
              isEmpty: false,
            ),
          ],

          // Tanda tangan
          const SizedBox(height: 14),
          _buildDetailRow(
            icon: Icons.draw_rounded,
            iconColor: AppTheme.softBlue,
            label: 'Tanda Tangan Mentor',
            value: '',
            isEmpty: note.signatureBase64.isEmpty,
            customContent: note.signatureBase64.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      height: 64,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: AppTheme.grey100),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Image.memory(
                        base64Decode(
                            note.signatureBase64.split(',').last),
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            const Center(
                          child: Icon(Icons.error_outline_rounded,
                              color: Colors.red, size: 20),
                        ),
                      ),
                    ),
                  )
                : Text(
                    '(Belum ada tanda tangan)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.grey400,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ── Detail row widget ──
  Widget _buildDetailRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required bool isEmpty,
    Widget? trailing,
    Widget? customContent,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.grey400,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (trailing != null) ...[
                    const Spacer(),
                    trailing,
                  ],
                ],
              ),
              const SizedBox(height: 4),
              if (customContent != null)
                customContent
              else
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isEmpty ? AppTheme.grey400 : AppTheme.textPrimary,
                    height: 1.4,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Status badge ──
  Widget _buildStatusBadge({
    required IconData icon,
    required String label,
    required bool filled,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: filled
            ? color.withValues(alpha: 0.08)
            : AppTheme.grey100.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 12,
              color: filled ? color : AppTheme.grey400),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: filled ? color : AppTheme.grey400,
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts.isNotEmpty && parts[0].isNotEmpty
        ? parts[0][0].toUpperCase()
        : '?';
  }
}
