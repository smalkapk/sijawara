import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../theme.dart';
import '../services/chat_service.dart';
import '../services/auth_service.dart';
import 'alka_ai_page.dart';
import 'guru_alka_ai_page.dart';
import 'wali_alka_ai_page.dart';

/// Halaman detail pesan chat
/// Menampilkan isi pesan, nama pengirim, tombol ALKA AI, dan info waktu
class ChatDetailPage extends StatefulWidget {
  final ChatMessage message;
  final String senderName;
  final String partnerName;
  final int currentUserId;

  const ChatDetailPage({
    super.key,
    required this.message,
    required this.senderName,
    required this.partnerName,
    required this.currentUserId,
  });

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  String _userRole = '';

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final role = await AuthService.getUserRole();
    if (mounted) setState(() => _userRole = role);
  }

  ChatMessage get msg => widget.message;

  String get _displaySenderName =>
      msg.isMe ? 'Anda' : widget.senderName;

  String _formatDateTime(DateTime dt) {
    return DateFormat('EEEE, d MMMM yyyy • HH:mm', 'id_ID').format(dt);
  }

  String get _messagePreview {
    if (msg.message == 'deleted') return 'Pesan telah dihapus';
    if (msg.isImage) return '📷 Foto';
    if (msg.isDocument) return '📄 ${msg.attachmentName ?? "Dokumen"}';
    return msg.message;
  }

  void _askAlkaAi() {
    final sender = _displaySenderName;
    final content = _messagePreview;
    final time = _formatDateTime(msg.createdAt);

    final contextMsg =
        'Berikut pesan dari percakapan chat di SIJAWARA yang ingin saya tanyakan:\n\n'
        '**Pengirim:** $sender\n'
        '**Waktu:** $time\n'
        '**Isi pesan:**\n> $content\n\n'
        'Silakan tanyakan apa saja tentang pesan ini. Saya siap membantu! 😊';

    Widget page;
    if (_userRole == 'guru_kelas') {
      page = GuruAlkaAiPage(initialContextMessage: contextMsg);
    } else if (_userRole == 'orang_tua') {
      page = WaliAlkaAiPage(initialContextMessage: contextMsg);
    } else {
      page = AlkaAiPage(initialContextMessage: contextMsg);
    }

    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildMessageCard(),
                    const SizedBox(height: 16),
                    _buildAlkaAiCard(),
                    const SizedBox(height: 16),
                    _buildInfoCard(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ── Header ──
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 16, 10),
      decoration: BoxDecoration(
        color: AppTheme.white,
        border: Border(
          bottom: BorderSide(color: AppTheme.grey100, width: 1),
        ),
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
          const SizedBox(width: 16),
          Text(
            'Detail Pesan',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
          ),
        ],
      ),
    );
  }

  /// ── Card isi pesan ──
  Widget _buildMessageCard() {
    final isDeleted = msg.message == 'deleted';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.grey100, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Isi pesan
          if (isDeleted)
            Row(
              children: [
                Icon(Icons.block_rounded,
                    size: 16,
                    color: AppTheme.grey400.withValues(alpha: 0.7)),
                const SizedBox(width: 6),
                Text(
                  'Pesan telah dihapus',
                  style: TextStyle(
                    fontSize: 15,
                    fontStyle: FontStyle.italic,
                    color: AppTheme.grey400.withValues(alpha: 0.9),
                  ),
                ),
              ],
            )
          else if (msg.isImage) ...[
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                color: AppTheme.grey100,
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: msg.attachmentUrl != null
                  ? Image.network(
                      msg.attachmentUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Center(
                        child: Icon(Icons.broken_image_rounded,
                            color: AppTheme.grey400, size: 40),
                      ),
                    )
                  : const Center(
                      child: Icon(Icons.image_rounded,
                          color: AppTheme.grey400, size: 40),
                    ),
            ),
            if (msg.message.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                msg.message,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppTheme.textPrimary,
                  height: 1.5,
                ),
              ),
            ],
          ] else if (msg.isDocument) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.bgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.grey100),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppTheme.softBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        msg.fileExtension,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.softBlue,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg.attachmentName ?? 'Dokumen',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          msg.fileSizeFormatted,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.grey400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (msg.message.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                msg.message,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppTheme.textPrimary,
                  height: 1.5,
                ),
              ),
            ],
          ] else
            Text(
              msg.message,
              style: const TextStyle(
                fontSize: 15,
                color: AppTheme.textPrimary,
                height: 1.5,
              ),
            ),

          const SizedBox(height: 16),
          const Divider(height: 1, color: AppTheme.grey100),
          const SizedBox(height: 12),

          // Nama pengirim
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor:
                    AppTheme.primaryGreen.withValues(alpha: 0.12),
                child: Text(
                  _getInitials(_displaySenderName),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _displaySenderName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// ── Card "Tanyakan ALKA AI" ──
  Widget _buildAlkaAiCard() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _askAlkaAi();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppTheme.teal.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.teal.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: AppTheme.teal,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tanyakan ALKA AI',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Diskusikan pesan ini dengan asisten cerdas SMALKA',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.grey400,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: AppTheme.teal.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }

  /// ── Card info waktu ──
  Widget _buildInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.grey100, width: 1),
      ),
      child: Column(
        children: [
          _buildInfoRow(
            icon: Icons.done_rounded,
            label: 'Waktu dikirim',
            value: _formatDateTime(msg.createdAt),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppTheme.grey100),
          const SizedBox(height: 14),
          _buildInfoRow(
            icon: msg.isRead
                ? Icons.done_all_rounded
                : Icons.done_rounded,
            iconColor: msg.isRead ? AppTheme.softBlue : AppTheme.grey400,
            label: 'Status',
            value: msg.isRead ? 'Sudah dibaca' : 'Belum dibaca',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? iconColor,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: (iconColor ?? AppTheme.grey400).withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: iconColor ?? AppTheme.grey400),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.grey400,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts.isNotEmpty ? parts[0][0].toUpperCase() : '?';
  }
}
