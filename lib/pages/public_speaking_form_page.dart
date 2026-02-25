import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../theme.dart';
import '../services/public_speaking_service.dart';

class PublicSpeakingFormPage extends StatefulWidget {
  final PublicSpeakingNote? note;

  const PublicSpeakingFormPage({super.key, this.note});

  @override
  State<PublicSpeakingFormPage> createState() => _PublicSpeakingFormPageState();
}

class _PublicSpeakingFormPageState extends State<PublicSpeakingFormPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  late DateTime _selectedDate;
  late TextEditingController _judulController;
  late TextEditingController _materiController;
  late TextEditingController _mentorController;
  late TextEditingController _noteController;
  bool _isSaving = false;
  bool _hasSaved = false;

  bool get _isEditing => widget.note != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Hide system navigation bar
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _fadeController.forward();

    _selectedDate = widget.note?.date ?? DateTime.now();
    _judulController = TextEditingController(text: widget.note?.judul ?? '');
    _materiController = TextEditingController(text: widget.note?.materi ?? '');
    _mentorController = TextEditingController(text: widget.note?.mentor ?? '');
    _noteController = TextEditingController(text: widget.note?.note ?? '');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // If app goes to background (recent apps / switch app) and hasn't saved, pop
    if (state == AppLifecycleState.paused && !_hasSaved) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _fadeController.dispose();
    _judulController.dispose();
    _materiController.dispose();
    _mentorController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    HapticFeedback.selectionClick();
    DateTime tempDate = _selectedDate;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              decoration: const BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.grey200,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Title
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_month_rounded,
                            size: 20, color: AppTheme.primaryGreen),
                        const SizedBox(width: 8),
                        Text(
                          'Pilih Tanggal',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => Navigator.pop(ctx),
                          child: Icon(Icons.close_rounded,
                              size: 22, color: AppTheme.grey400),
                        ),
                      ],
                    ),
                  ),
                  // Calendar
                  Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: ColorScheme.light(
                        primary: AppTheme.primaryGreen,
                        onPrimary: Colors.white,
                        surface: AppTheme.white,
                        onSurface: AppTheme.textPrimary,
                      ),
                    ),
                    child: CalendarDatePicker(
                      initialDate: tempDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                      onDateChanged: (date) {
                        tempDate = date;
                      },
                    ),
                  ),
                  // Confirm button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx, tempDate);
                      },
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
                            'Pilih Tanggal',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        );
      },
    ).then((result) {
      if (result != null && result is DateTime) {
        setState(() => _selectedDate = result);
      }
    });
  }

  Future<void> _saveNote() async {
    if (_materiController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Materi tidak boleh kosong'),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      if (_isEditing) {
        final updated = widget.note!.copyWith(
          date: _selectedDate,
          judul: _judulController.text.trim(),
          materi: _materiController.text.trim(),
          mentor: _mentorController.text.trim(),
          note: _noteController.text.trim(),
        );
        await PublicSpeakingService.updateNote(updated);
      } else {
        final note = PublicSpeakingNote(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          date: _selectedDate,
          judul: _judulController.text.trim(),
          materi: _materiController.text.trim(),
          mentor: _mentorController.text.trim(),
          note: _noteController.text.trim(),
        );
        await PublicSpeakingService.addNote(note);
      }

      if (!mounted) return;
      setState(() => _hasSaved = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'Catatan berhasil diperbarui'
                : 'Catatan berhasil disimpan',
          ),
          backgroundColor: AppTheme.primaryGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      Navigator.of(context).pop(_isEditing ? 'edit' : 'new');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan: $e'),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        // Block back gesture/button - user must submit or app goes background
        if (didPop) return;
      },
      child: Scaffold(
        backgroundColor: AppTheme.bgColor,
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDateField(),
                        const SizedBox(height: 20),
                        _buildJudulField(),
                        const SizedBox(height: 20),
                        _buildMateriField(),
                        const SizedBox(height: 20),
                        _buildMentorField(),
                        const SizedBox(height: 20),
                        _noteField(),
                        const SizedBox(height: 32),
                        _buildSaveButton(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ──
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.edit_note_rounded,
                        size: 14, color: AppTheme.softPurple),
                    const SizedBox(width: 6),
                    Text(
                      _isEditing ? 'Edit Catatan' : 'Catatan Baru',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Public Speaking',
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

  // ── Date Field ──
  Widget _buildDateField() {
    final dateFormat = DateFormat('EEEE, d MMMM yyyy', 'id_ID');
    final formattedDate = dateFormat.format(_selectedDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('Hari / Tanggal', Icons.calendar_today_rounded),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickDate,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              boxShadow: AppTheme.softShadow,
              border: Border.all(
                color: AppTheme.primaryGreen.withOpacity(0.15),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.calendar_month_rounded,
                    size: 20,
                    color: AppTheme.primaryGreen,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    formattedDate,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppTheme.grey400,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Judul Field ──
  Widget _buildJudulField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('Judul', Icons.title_rounded),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            boxShadow: AppTheme.softShadow,
            border: Border.all(
              color: AppTheme.primaryGreen.withOpacity(0.15),
              width: 1.5,
            ),
          ),
          child: TextField(
            controller: _judulController,
            maxLines: 1,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
              height: 1.6,
            ),
            decoration: InputDecoration(
              hintText: 'Tulis judul catatan...',
              hintStyle: TextStyle(
                fontSize: 15,
                color: AppTheme.grey400.withOpacity(0.6),
                height: 1.6,
              ),
              contentPadding: const EdgeInsets.all(16),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  // ── Materi Field ──
  Widget _buildMateriField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('Materi', Icons.subject_rounded),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            boxShadow: AppTheme.softShadow,
            border: Border.all(
              color: AppTheme.primaryGreen.withOpacity(0.15),
              width: 1.5,
            ),
          ),
          child: TextField(
            controller: _materiController,
            maxLines: 8,
            minLines: 5,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: AppTheme.textPrimary,
              height: 1.6,
            ),
            decoration: InputDecoration(
              hintText: 'Tulis materi public speaking di sini...\nContoh:\n- Topik presentasi\n- Poin-poin penting\n- Catatan tambahan',
              hintStyle: TextStyle(
                fontSize: 14,
                color: AppTheme.grey400.withOpacity(0.6),
                height: 1.6,
              ),
              contentPadding: const EdgeInsets.all(16),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  // ── Mentor Field ──
  Widget _buildMentorField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('Nama Mentor', Icons.person_rounded),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            boxShadow: AppTheme.softShadow,
            border: Border.all(
              color: AppTheme.softPurple.withOpacity(0.15),
              width: 1.5,
            ),
          ),
          child: TextField(
            controller: _mentorController,
            maxLines: 3,
            minLines: 2,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: AppTheme.textPrimary,
              height: 1.6,
            ),
            decoration: InputDecoration(
              hintText: 'Tulis nama mentor disini',
              hintStyle: TextStyle(
                fontSize: 14,
                color: AppTheme.grey400.withOpacity(0.6),
                height: 1.6,
              ),
              contentPadding: const EdgeInsets.all(16),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

    // ── Note Field ──
  Widget _noteField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('Catatan', Icons.note_rounded),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            boxShadow: AppTheme.softShadow,
            border: Border.all(
              color: AppTheme.softPurple.withOpacity(0.15),
              width: 1.5,
            ),
          ),
          child: TextField(
            controller: _noteController,
            maxLines: 3,
            minLines: 2,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: AppTheme.textPrimary,
              height: 1.6,
            ),
            decoration: InputDecoration(
              hintText: 'Tulis catatan disini',
              hintStyle: TextStyle(
                fontSize: 14,
                color: AppTheme.grey400.withOpacity(0.6),
                height: 1.6,
              ),
              contentPadding: const EdgeInsets.all(16),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  // ── Field Label ──
  Widget _buildFieldLabel(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.primaryGreen),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  // ── Save Button ──
  Widget _buildSaveButton() {
    return GestureDetector(
      onTap: _isSaving ? null : () {
        HapticFeedback.mediumImpact();
        _saveNote();
      },
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
            const SizedBox(width: 10),
            Text(
              _isSaving
                  ? 'Menyimpan...'
                  : _isEditing
                      ? 'Perbarui Catatan'
                      : 'Simpan Catatan',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
