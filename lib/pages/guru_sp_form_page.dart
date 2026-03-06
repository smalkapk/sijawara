import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../services/guru_sp_service.dart';

class GuruSpFormPage extends StatefulWidget {
  final bool isEditing;
  final Map<String, dynamic>? initialData;
  final Map<String, dynamic> studentData;

  const GuruSpFormPage({
    super.key,
    this.isEditing = false,
    this.initialData,
    required this.studentData,
  });

  @override
  State<GuruSpFormPage> createState() => _GuruSpFormPageState();
}

class _GuruSpFormPageState extends State<GuruSpFormPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  late DateTime _selectedDate;
  final _jenisSpController = TextEditingController();
  final _alasanController = TextEditingController();
  final _tindakanController = TextEditingController();
  final _noteController = TextEditingController();
  bool _isSaving = false;

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

    _selectedDate = DateTime.now();
    if (widget.isEditing && widget.initialData != null) {
      if (widget.initialData!['date'] != null) {
        try {
          // Attempt to parse if it's a valid string format "dd-MM-yyyy"
          final parts = widget.initialData!['date'].split('-');
          if (parts.length == 3) {
            _selectedDate = DateTime(
              int.parse(parts[2]),
              int.parse(parts[1]),
              int.parse(parts[0]),
            );
          }
        } catch (_) {}
      }
      _jenisSpController.text = widget.initialData!['jenis_sp'] ?? '';
      _alasanController.text = widget.initialData!['alasan'] ?? '';
      _tindakanController.text = widget.initialData!['tindakan'] ?? '';
      _noteController.text = widget.initialData!['note'] ?? '';
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _jenisSpController.dispose();
    _alasanController.dispose();
    _tindakanController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    HapticFeedback.selectionClick();
    final tempDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryGreen,
              onPrimary: Colors.white,
              surface: AppTheme.white,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (tempDate != null) {
      setState(() {
        _selectedDate = tempDate;
      });
    }
  }

  int get _studentId => widget.studentData['student_id'] is int
      ? widget.studentData['student_id']
      : int.tryParse(widget.studentData['student_id']?.toString() ?? '0') ?? 0;

  Future<void> _saveForm() async {
    HapticFeedback.mediumImpact();
    if (_jenisSpController.text.isEmpty || _alasanController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Jenis SP dan Alasan wajib diisi'),
          backgroundColor: Colors.red.shade400,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryGreen),
      ),
    );

    final spDate =
        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

    try {
      if (widget.isEditing && widget.initialData?['id'] != null) {
        await GuruSpService.updateReport(
          reportId: widget.initialData!['id'].toString(),
          studentId: _studentId,
          spDate: spDate,
          jenisSp: _jenisSpController.text.trim(),
          alasan: _alasanController.text.trim(),
          tindakan: _tindakanController.text.trim(),
          note: _noteController.text.trim(),
        );
      } else {
        await GuruSpService.addReport(
          studentId: _studentId,
          spDate: spDate,
          jenisSp: _jenisSpController.text.trim(),
          alasan: _alasanController.text.trim(),
          tindakan: _tindakanController.text.trim(),
          note: _noteController.text.trim(),
        );
      }

      if (mounted) {
        setState(() => _isSaving = false);
        Navigator.pop(context); // Close loading
        Navigator.pop(context, true); // Go back with success
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isEditing
                ? 'Laporan SP berhasil diperbarui'
                : 'Laporan SP berhasil disimpan'),
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
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan: $e'),
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
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDateField(),
                      const SizedBox(height: 16),
                      _buildInputField('Jenis SP', _jenisSpController, Icons.warning_amber_rounded),
                      const SizedBox(height: 16),
                      _buildInputField('Alasan/Pelanggaran', _alasanController, Icons.gavel_rounded, maxLines: 4),
                      const SizedBox(height: 16),
                      _buildInputField('Tindakan', _tindakanController, Icons.assignment_turned_in_rounded, maxLines: 3),
                      const SizedBox(height: 16),
                      _buildInputField('Catatan Tambahan', _noteController, Icons.notes_rounded, maxLines: 3),
                      const SizedBox(height: 80),
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

  Widget _buildDateField() {
    final formattedDate = "${_selectedDate.day.toString().padLeft(2, '0')}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.year}";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.calendar_today_rounded, size: 16, color: AppTheme.primaryGreen),
            const SizedBox(width: 8),
            const Text(
              'Tanggal',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickDate,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.grey100, width: 1),
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

  Widget _buildHeader(BuildContext context) {
    final title = widget.isEditing ? 'Edit Laporan SP' : 'Input Laporan SP';

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
                      Icons.assignment_rounded,
                      size: 14,
                      color: AppTheme.gold,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.studentData['name'],
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

  Widget _buildInputField(String label, TextEditingController controller, IconData icon, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
           children: [
             Icon(icon, size: 16, color: AppTheme.primaryGreen),
             const SizedBox(width: 8),
             Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
             ),
           ]
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.grey100, width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            crossAxisAlignment: maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  maxLines: maxLines,
                  minLines: maxLines > 1 ? 3 : 1,
                  decoration: InputDecoration(
                    hintText: 'Tulis $label...',
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: AppTheme.grey400,
                      fontWeight: FontWeight.w500,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: maxLines > 1 ? 12 : 16),
                  ),
                ),
              ),
            ],
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
                  _isSaving ? 'Menyimpan...' : 'Simpan Laporan',
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
}
