import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../services/diskusi_guru_service.dart';

class WaliDiskusiGuruFormPage extends StatefulWidget {
  final DiskusiGuruNote? note; // If null, means create new
  const WaliDiskusiGuruFormPage({super.key, this.note});

  @override
  State<WaliDiskusiGuruFormPage> createState() =>
      _WaliDiskusiGuruFormPageState();
}

class _WaliDiskusiGuruFormPageState extends State<WaliDiskusiGuruFormPage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _topikCtrl;
  late TextEditingController _namaGuruCtrl;
  late TextEditingController _pesanCtrl;

  bool _isSaving = false;
  late bool _isEditMode;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.note != null;

    _topikCtrl = TextEditingController(text: widget.note?.topik ?? '');
    _namaGuruCtrl = TextEditingController(text: widget.note?.namaGuru ?? '');
    _pesanCtrl = TextEditingController(text: widget.note?.pesan ?? '');
  }

  @override
  void dispose() {
    _topikCtrl.dispose();
    _namaGuruCtrl.dispose();
    _pesanCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveNote() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    HapticFeedback.lightImpact();

    try {
      final now = DateTime.now();

      if (_isEditMode) {
        final updated = widget.note!.copyWith(
          topik: _topikCtrl.text.trim(),
          namaGuru: _namaGuruCtrl.text.trim(),
          pesan: _pesanCtrl.text.trim(),
        );
        await DiskusiGuruService.updateNote(updated);
      } else {
        final newNote = DiskusiGuruNote(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          date: now,
          topik: _topikCtrl.text.trim(),
          namaGuru: _namaGuruCtrl.text.trim(),
          pesan: _pesanCtrl.text.trim(),
          balasan: '', // Balasan guru initially empty
          createdAt: now,
        );
        await DiskusiGuruService.addNote(newNote);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditMode
                ? 'Diskusi berhasil diperbarui'
                : 'Diskusi berhasil ditambahkan',
          ),
          backgroundColor: AppTheme.primaryGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      Navigator.pop(context, _isEditMode ? 'edit' : 'new');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          _isEditMode ? 'Edit Diskusi' : 'Diskusi Baru',
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppTheme.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _saveNote,
              child: const Text(
                'Simpan',
                style: TextStyle(
                  color: AppTheme.primaryGreen,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: DefaultTextStyle(
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w500,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Form header info
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.primaryGreen.withOpacity(0.1),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: AppTheme.primaryGreen,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Kirimkan pesan ke guru wali kelas atau guru mata pelajaran terkait kondisi siswa.',
                            style: TextStyle(height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Fields
                  _buildLabel('Topik Diskusi'),
                  _buildTextField(
                    controller: _topikCtrl,
                    hint: 'Misal: Izin Sakit, Pertanyaan Tugas',
                    icon: Icons.title_rounded,
                    validator: (v) =>
                        v!.isEmpty ? 'Topik tidak boleh kosong' : null,
                  ),
                  const SizedBox(height: 20),

                  _buildLabel('Nama Guru Tujuan'),
                  _buildTextField(
                    controller: _namaGuruCtrl,
                    hint: 'Misal: Ust. Fulan / Wali Kelas',
                    icon: Icons.person_search_rounded,
                    validator: (v) =>
                        v!.isEmpty ? 'Nama guru tidak boleh kosong' : null,
                  ),
                  const SizedBox(height: 20),

                  _buildLabel('Pesan'),
                  _buildTextField(
                    controller: _pesanCtrl,
                    hint:
                        'Tuliskan pesan atau diskusi yang ingin disampaikan...',
                    icon: Icons.message_rounded,
                    maxLines: 5,
                    validator: (v) =>
                        v!.isEmpty ? 'Pesan tidak boleh kosong' : null,
                  ),
                  const SizedBox(height: 20),

                  if (_isEditMode &&
                      widget.note?.balasan.isNotEmpty == true) ...[
                    _buildLabel('Balasan Guru'),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.grey100,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                      child: Text(
                        widget.note!.balasan,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontStyle: FontStyle.italic,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: AppTheme.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppTheme.grey400, fontSize: 14),
        filled: true,
        fillColor: AppTheme.white,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 20,
          vertical: maxLines > 1 ? 16 : 0,
        ),
        prefixIcon: maxLines == 1
            ? Icon(icon, color: AppTheme.grey400, size: 20)
            : Padding(
                padding: const EdgeInsets.only(bottom: 80),
                child: Icon(icon, color: AppTheme.grey400, size: 20),
              ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          borderSide: BorderSide(color: AppTheme.grey200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          borderSide: const BorderSide(
            color: AppTheme.primaryGreen,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
      ),
      validator: validator,
    );
  }
}
