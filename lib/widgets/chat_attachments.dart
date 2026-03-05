import 'dart:io';
import 'package:flutter/material.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme.dart';
import '../services/chat_service.dart';

// ═══════════════════════════════════════════════════
// EMOJI PICKER WIDGET
// ═══════════════════════════════════════════════════

/// Emoji picker bottomsheet widget
class ChatEmojiPicker extends StatelessWidget {
  final TextEditingController textController;
  final VoidCallback? onEmojiSelected;

  const ChatEmojiPicker({
    super.key,
    required this.textController,
    this.onEmojiSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                const Text(
                  'Pilih Emoji',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF303030),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.grey),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          // Divider
          Divider(height: 1, color: Colors.grey[200]),
          // Emoji grid
          SizedBox(
            height: 300,
            child: EmojiPicker(
              textEditingController: textController,
              onEmojiSelected: (_, __) {
                onEmojiSelected?.call();
              },
              config: Config(
                height: 300,
                emojiViewConfig: EmojiViewConfig(
                  columns: 8,
                  emojiSizeMax: 28,
                  backgroundColor: const Color(0xFFF7F7F7),
                ),
                categoryViewConfig: CategoryViewConfig(
                  indicatorColor: AppTheme.primaryGreen,
                  iconColorSelected: AppTheme.primaryGreen,
                  backspaceColor: AppTheme.primaryGreen,
                  backgroundColor: const Color(0xFFF7F7F7),
                ),
                bottomActionBarConfig: const BottomActionBarConfig(
                  enabled: false,
                ),
                searchViewConfig: const SearchViewConfig(
                  hintText: 'Cari emoji...',
                  backgroundColor: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Show emoji picker as bottomsheet
  static void show(
    BuildContext context, {
    required TextEditingController controller,
    VoidCallback? onEmojiSelected,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFF7F7F7),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ChatEmojiPicker(
        textController: controller,
        onEmojiSelected: onEmojiSelected,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// ATTACHMENT PICKER (DOCUMENT)
// ═══════════════════════════════════════════════════

class ChatAttachmentPicker {
  /// Show attachment options bottomsheet
  static void show(
    BuildContext context, {
    required Future<void> Function(File file, String type) onFilePicked,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Kirim Lampiran',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF303030),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _AttachOption(
                    icon: Icons.photo_library_rounded,
                    label: 'Galeri',
                    color: const Color(0xFF7C4DFF),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showSizeWarningSheet(
                        context,
                        maxMB: 10,
                        type: 'gambar',
                        onConfirm: () async {
                          final picker = ImagePicker();
                          final img = await picker.pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 80,
                            maxWidth: 1920,
                          );
                          if (img != null) {
                            await onFilePicked(File(img.path), 'image');
                          }
                        },
                      );
                    },
                  ),
                  _AttachOption(
                    icon: Icons.insert_drive_file_rounded,
                    label: 'Dokumen',
                    color: const Color(0xFF0091EA),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showSizeWarningSheet(
                        context,
                        maxMB: 25,
                        type: 'dokumen',
                        onConfirm: () async {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: [
                              'pdf',
                              'doc',
                              'docx',
                              'xls',
                              'xlsx',
                              'ppt',
                              'pptx',
                              'txt'
                            ],
                          );
                          if (result != null &&
                              result.files.single.path != null) {
                            await onFilePicked(
                                File(result.files.single.path!), 'document');
                          }
                        },
                      );
                    },
                  ),
                  _AttachOption(
                    icon: Icons.camera_alt_rounded,
                    label: 'Kamera',
                    color: const Color(0xFFE91E63),
                    onTap: () {
                      Navigator.pop(ctx);
                      ChatCameraPicker.show(context, onPhotoTaken: (file) async {
                        await onFilePicked(file, 'image');
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Tampilkan bottom sheet peringatan ukuran file sebelum membuka picker.
  /// [maxMB] batas maksimum (MB), [type] label jenis file (gambar/dokumen).
  static void _showSizeWarningSheet(
    BuildContext context, {
    required int maxMB,
    required String type,
    required Future<void> Function() onConfirm,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.info_outline_rounded,
                  size: 36,
                  color: Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(height: 16),

              // Judul
              Text(
                'Perhatikan Ukuran File',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 10),

              // Pesan ukuran
              Text(
                'Pastikan ukuran $type Anda di bawah ${maxMB}MB',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1B8A4A),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),

              // Pesan peringatan
              Text(
                'Kami menolak $type dengan ukuran lebih dari ${maxMB}MB. '
                'Silahkan bijak dalam mengupload file agar pengalaman '
                'komunikasi tetap lancar.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),

              // Tombol Lanjutkan
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    onConfirm();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Lanjutkan',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 0),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttachOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AttachOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// CAMERA PICKER (FULLSCREEN CAMERA → REVIEW → SEND)
// ═══════════════════════════════════════════════════

class ChatCameraPicker {
  static void show(
    BuildContext context, {
    required Future<void> Function(File file) onPhotoTaken,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _CameraReviewPage(onPhotoTaken: onPhotoTaken),
      ),
    );
  }
}

class _CameraReviewPage extends StatefulWidget {
  final Future<void> Function(File file) onPhotoTaken;

  const _CameraReviewPage({required this.onPhotoTaken});

  @override
  State<_CameraReviewPage> createState() => _CameraReviewPageState();
}

class _CameraReviewPageState extends State<_CameraReviewPage> {
  File? _capturedFile;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _takePhoto();
  }

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (img != null) {
      if (mounted) setState(() => _capturedFile = File(img.path));
    } else {
      // User cancelled camera
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _retake() async {
    setState(() => _capturedFile = null);
    await _takePhoto();
  }

  Future<void> _send() async {
    if (_capturedFile == null || _isSending) return;
    setState(() => _isSending = true);
    await widget.onPhotoTaken(_capturedFile!);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_capturedFile == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryGreen),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'Pratinjau',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 48), // Balance
                ],
              ),
            ),
            // Image preview
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.file(
                  _capturedFile!,
                  fit: BoxFit.contain,
                  width: double.infinity,
                ),
              ),
            ),
            // Bottom actions
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: Row(
                children: [
                  // Retake button
                  Expanded(
                    child: GestureDetector(
                      onTap: _retake,
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.replay_rounded,
                                color: Colors.white, size: 22),
                            SizedBox(width: 8),
                            Text(
                              'Ulangi',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Send button
                  Expanded(
                    child: GestureDetector(
                      onTap: _send,
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen,
                          borderRadius: BorderRadius.circular(26),
                        ),
                        child: _isSending
                            ? const Center(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.send_rounded,
                                      color: Colors.white, size: 22),
                                  SizedBox(width: 8),
                                  Text(
                                    'Kirim',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
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
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// IMAGE VIEWER (FULLSCREEN)
// ═══════════════════════════════════════════════════

class ChatImageViewer extends StatelessWidget {
  final String imageUrl;
  final String? senderName;

  const ChatImageViewer({
    super.key,
    required this.imageUrl,
    this.senderName,
  });

  static void show(BuildContext context,
      {required String url, String? senderName}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatImageViewer(imageUrl: url, senderName: senderName),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(senderName ?? 'Foto',
            style: const TextStyle(fontSize: 16, color: Colors.white)),
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: progress.expectedTotalBytes != null
                      ? progress.cumulativeBytesLoaded /
                          progress.expectedTotalBytes!
                      : null,
                  color: AppTheme.primaryGreen,
                ),
              );
            },
            errorBuilder: (_, __, ___) => const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image_rounded, color: Colors.white54, size: 64),
                SizedBox(height: 12),
                Text('Gagal memuat gambar',
                    style: TextStyle(color: Colors.white54)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// MESSAGE BUBBLE WIDGETS (for image & document)
// ═══════════════════════════════════════════════════

/// Bubble khusus untuk pesan gambar
class ImageMessageBubble extends StatelessWidget {
  final ChatMessage msg;
  final String Function(DateTime) formatTime;

  const ImageMessageBubble({
    super.key,
    required this.msg,
    required this.formatTime,
  });

  @override
  Widget build(BuildContext context) {
    final isMe = msg.isMe;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 3),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFFDCF8C6) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(8),
            topRight: const Radius.circular(8),
            bottomLeft:
                isMe ? const Radius.circular(8) : const Radius.circular(0),
            bottomRight:
                isMe ? const Radius.circular(0) : const Radius.circular(8),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Image
            GestureDetector(
              onTap: () {
                if (msg.attachmentUrl != null) {
                  ChatImageViewer.show(context, url: msg.attachmentUrl!);
                }
              },
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
                child: msg.attachmentUrl != null
                    ? Image.network(
                        msg.attachmentUrl!,
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                        loadingBuilder: (_, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            width: double.infinity,
                            height: 200,
                            color: Colors.grey[200],
                            child: Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.primaryGreen,
                                value: progress.expectedTotalBytes != null
                                    ? progress.cumulativeBytesLoaded /
                                        progress.expectedTotalBytes!
                                    : null,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (_, __, ___) => Container(
                          width: double.infinity,
                          height: 200,
                          color: Colors.grey[200],
                          child: const Icon(Icons.broken_image_rounded,
                              color: Colors.grey, size: 48),
                        ),
                      )
                    : Container(
                        width: double.infinity,
                        height: 200,
                        color: Colors.grey[200],
                        child: const Icon(Icons.image, color: Colors.grey),
                      ),
              ),
            ),
            // Caption + time + read
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (msg.message.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        msg.message,
                        style: const TextStyle(
                          color: Color(0xFF303030),
                          fontSize: 14,
                          height: 1.3,
                        ),
                      ),
                    ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Spacer(),
                      Text(
                        formatTime(msg.createdAt),
                        style: TextStyle(
                          color: isMe
                              ? const Color(0xFF6D9B78)
                              : const Color(0xFF9BA5A5),
                          fontSize: 11,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          msg.isRead
                              ? Icons.done_all_rounded
                              : Icons.done_rounded,
                          size: 16,
                          color: msg.isRead
                              ? const Color(0xFF53BDEB)
                              : const Color(0xFF8FAE96),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bubble khusus untuk pesan dokumen
class DocumentMessageBubble extends StatelessWidget {
  final ChatMessage msg;
  final String Function(DateTime) formatTime;

  const DocumentMessageBubble({
    super.key,
    required this.msg,
    required this.formatTime,
  });

  Color _getDocColor(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf':
        return const Color(0xFFE53935);
      case 'doc':
      case 'docx':
        return const Color(0xFF1565C0);
      case 'xls':
      case 'xlsx':
        return const Color(0xFF2E7D32);
      case 'ppt':
      case 'pptx':
        return const Color(0xFFE65100);
      default:
        return const Color(0xFF546E7A);
    }
  }

  IconData _getDocIcon(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'doc':
      case 'docx':
        return Icons.description_rounded;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart_rounded;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMe = msg.isMe;
    final ext = msg.fileExtension;
    final docColor = _getDocColor(ext);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 3),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFFDCF8C6) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(8),
            topRight: const Radius.circular(8),
            bottomLeft:
                isMe ? const Radius.circular(8) : const Radius.circular(0),
            bottomRight:
                isMe ? const Radius.circular(0) : const Radius.circular(8),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Document card
            GestureDetector(
              onTap: () async {
                if (msg.attachmentUrl != null) {
                  final uri = Uri.parse(msg.attachmentUrl!);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                }
              },
              child: Container(
                margin: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: docColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: docColor.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: docColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(_getDocIcon(ext), color: docColor, size: 24),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            msg.attachmentName ?? 'Dokumen',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF303030),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${ext.isNotEmpty ? "$ext • " : ""}${msg.fileSizeFormatted}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.download_rounded,
                        color: docColor.withValues(alpha: 0.6), size: 22),
                  ],
                ),
              ),
            ),
            // Caption + time
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (msg.message.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        msg.message,
                        style: const TextStyle(
                          color: Color(0xFF303030),
                          fontSize: 14,
                          height: 1.3,
                        ),
                      ),
                    ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Spacer(),
                      Text(
                        formatTime(msg.createdAt),
                        style: TextStyle(
                          color: isMe
                              ? const Color(0xFF6D9B78)
                              : const Color(0xFF9BA5A5),
                          fontSize: 11,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          msg.isRead
                              ? Icons.done_all_rounded
                              : Icons.done_rounded,
                          size: 16,
                          color: msg.isRead
                              ? const Color(0xFF53BDEB)
                              : const Color(0xFF8FAE96),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
