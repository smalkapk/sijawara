import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../services/aduan_aplikasi_service.dart';

class WaliAduanAplikasiFormPage extends StatefulWidget {
  final AduanAplikasiTicket? ticket; // If null, means create new
  const WaliAduanAplikasiFormPage({super.key, this.ticket});

  @override
  State<WaliAduanAplikasiFormPage> createState() =>
      _WaliAduanAplikasiFormPageState();
}

class _WaliAduanAplikasiFormPageState extends State<WaliAduanAplikasiFormPage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _judulCtrl;
  late TextEditingController _deskripsiCtrl;

  bool _isSaving = false;
  late bool _isEditMode;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.ticket != null;

    _judulCtrl = TextEditingController(text: widget.ticket?.judul ?? '');
    _deskripsiCtrl = TextEditingController(
      text: widget.ticket?.deskripsi ?? '',
    );
  }

  @override
  void dispose() {
    _judulCtrl.dispose();
    _deskripsiCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveTicket() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    HapticFeedback.lightImpact();

    try {
      final now = DateTime.now();

      if (_isEditMode) {
        final updated = widget.ticket!.copyWith(
          judul: _judulCtrl.text.trim(),
          deskripsi: _deskripsiCtrl.text.trim(),
        );
        await AduanAplikasiService.updateTicket(updated);
      } else {
        final newTicket = AduanAplikasiTicket(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          date: now,
          judul: _judulCtrl.text.trim(),
          deskripsi: _deskripsiCtrl.text.trim(),
          status: 'Menunggu',
          tanggapan: '', // Tanggapan admin initially empty
          createdAt: now,
        );
        await AduanAplikasiService.addTicket(newTicket);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditMode
                ? 'Aduan berhasil diperbarui'
                : 'Aduan berhasil dikirim',
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
          _isEditMode ? 'Edit Aduan' : 'Aduan Baru',
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
              onPressed: _saveTicket,
              child: const Text(
                'Kirim',
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
                      color: AppTheme.softPurple.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.softPurple.withOpacity(0.1),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.bug_report_rounded,
                          color: AppTheme.softPurple,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Laporkan masalah aplikasi, saran fitur, atau kendala teknis yang Anda alami saat menggunakan Sijawara.',
                            style: TextStyle(height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Fields
                  _buildLabel('Judul Aduan'),
                  _buildTextField(
                    controller: _judulCtrl,
                    hint: 'Misal: Fitur Notifikasi Tidak Berjalan',
                    icon: Icons.title_rounded,
                    validator: (v) =>
                        v!.isEmpty ? 'Judul tidak boleh kosong' : null,
                  ),
                  const SizedBox(height: 20),

                  _buildLabel('Deskripsi Keluhan'),
                  _buildTextField(
                    controller: _deskripsiCtrl,
                    hint: 'Jelaskan rincian kendala secara detail...',
                    icon: Icons.description_rounded,
                    maxLines: 6,
                    validator: (v) =>
                        v!.isEmpty ? 'Deskripsi tidak boleh kosong' : null,
                  ),
                  const SizedBox(height: 20),

                  if (_isEditMode &&
                      widget.ticket?.status != 'Menunggu' &&
                      widget.ticket?.tanggapan.isNotEmpty == true) ...[
                    _buildLabel('Tanggapan Admin (${widget.ticket!.status})'),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.grey100,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                      child: Text(
                        widget.ticket!.tanggapan,
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
                padding: const EdgeInsets.only(bottom: 104),
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
