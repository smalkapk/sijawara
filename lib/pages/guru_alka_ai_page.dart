import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../theme.dart';
import '../services/alka_ai_service.dart';
import 'guru_diskusi_wali_page.dart';
import 'guru_maklumat_page.dart';
import 'guru_profile_page.dart';
import 'guru_siswa_page.dart';
import 'guru_tugas_page.dart';

// ───────────────────────────────────────────────
//  Navigation config for [NAV:xxx] markers
// ───────────────────────────────────────────────

class _NavAction {
  final String label;
  final IconData icon;
  final Widget Function() pageBuilder;

  const _NavAction({
    required this.label,
    required this.icon,
    required this.pageBuilder,
  });
}

final Map<String, _NavAction> _navActions = {
  'diskusi_wali': _NavAction(
    label: 'Buka Halaman Diskusi Wali',
    icon: Icons.mail_rounded,
    pageBuilder: () => const GuruDiskusiWaliPage(),
  ),
  'maklumat': _NavAction(
    label: 'Buka Halaman Maklumat',
    icon: Icons.notifications_active_rounded,
    pageBuilder: () => const GuruMaklumatPage(),
  ),
  'tugas': _NavAction(
    label: 'Buka Halaman Tugas',
    icon: Icons.assignment_rounded,
    pageBuilder: () => const GuruTugasPage(),
  ),
  'profil': _NavAction(
    label: 'Buka Halaman Profil',
    icon: Icons.person_rounded,
    pageBuilder: () => const GuruProfilePage(),
  ),
  'live': _NavAction(
    label: 'Buka Halaman Daftar Siswa',
    icon: Icons.people_alt_rounded,
    pageBuilder: () => const GuruSiswaPage(),
  ),
};

// Parse [NAV:xxx] from a message and return (cleanText, navId)
(String, String?) _parseNavMarker(String content) {
  final regex = RegExp(r'\[NAV:(\w+)\]');
  final match = regex.firstMatch(content);
  if (match != null) {
    final navId = match.group(1)!;
    final cleanText = content.replaceAll(regex, '').trimRight();
    return (cleanText, navId);
  }
  return (content, null);
}

// ───────────────────────────────────────────────
//  Conversation history model
// ───────────────────────────────────────────────

class _ChatSession {
  final String title;
  final DateTime createdAt;
  final List<LlmMessage> messages;

  _ChatSession({
    required this.title,
    required this.createdAt,
    required this.messages,
  });
}

// ───────────────────────────────────────────────
//  Main Page
// ───────────────────────────────────────────────

class GuruAlkaAiPage extends StatefulWidget {
  final String? initialContextMessage;

  const GuruAlkaAiPage({super.key, this.initialContextMessage});

  @override
  State<GuruAlkaAiPage> createState() => _GuruAlkaAiPageState();
}

class _GuruAlkaAiPageState extends State<GuruAlkaAiPage> {
  // Static: persists across page visits within the same app session
  static final List<LlmMessage> _messages = [];
  static final List<_ChatSession> _chatHistory = [];

  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  static const String _welcomeMsg =
      'Halo! Saya ALKA AI, asisten virtual Sijawara. Ada yang bisa saya bantu hari ini? 😊\n\nSaya bisa membantu Anda tentang fitur-fitur aplikasi seperti **Diskusi Wali**, **Tugas**, **Maklumat**, dan lainnya.';

  @override
  void initState() {
    super.initState();

    if (widget.initialContextMessage != null) {
      // Simpan percakapan saat ini jika ada pesan dari user
      final hasUserMessages = _messages.any((m) => m.role == 'user');
      if (hasUserMessages) {
        final firstUserMsg = _messages.firstWhere((m) => m.role == 'user');
        _chatHistory.insert(
          0,
          _ChatSession(
            title: firstUserMsg.content,
            createdAt: DateTime.now(),
            messages: List.from(_messages),
          ),
        );
      }

      // Mulai percakapan baru dengan konteks sbg pengawal
      _messages.clear();
      _messages.add(
        LlmMessage(role: 'assistant', content: widget.initialContextMessage!),
      );
    } else {
      // Masuk tanpa konteks (dari Home Grid)
      if (_messages.isEmpty) {
        _messages.add(LlmMessage(role: 'assistant', content: _welcomeMsg));
      } else if (_messages.first.content != _welcomeMsg) {
        // Obrolan saat ini adalah obrolan kontekstual, mari kita simpan (jika ada pesan user)
        // dan mulai obrolan global baru yang bersih.
        final hasUserMessages = _messages.any((m) => m.role == 'user');
        if (hasUserMessages) {
          final firstUserMsg = _messages.firstWhere((m) => m.role == 'user');
          _chatHistory.insert(
            0,
            _ChatSession(
              title: firstUserMsg.content,
              createdAt: DateTime.now(),
              messages: List.from(_messages),
            ),
          );
        }
        _messages.clear();
        _messages.add(LlmMessage(role: 'assistant', content: _welcomeMsg));
      }
      // Jika _messages.first.content == _welcomeMsg, berarti ini adalah
      // obrolan global biasa, biarkan persisten.
    }
  }

  @override
  void dispose() {
    _msgController.dispose();

    _scrollController.dispose();
    super.dispose();
  }

  // ── Conversation management ──

  void _startNewConversation() {
    // Save current conversation if it has user messages
    final hasUserMessages = _messages.any((m) => m.role == 'user');
    if (hasUserMessages) {
      final firstUserMsg = _messages.firstWhere((m) => m.role == 'user');
      _chatHistory.insert(
        0,
        _ChatSession(
          title: firstUserMsg.content,
          createdAt: DateTime.now(),
          messages: List.from(_messages),
        ),
      );
    }

    setState(() {
      _messages.clear();
      _messages.add(LlmMessage(role: 'assistant', content: _welcomeMsg));
    });
  }

  void _loadConversation(int historyIndex) {
    // Save current if needed
    final hasUserMessages = _messages.any((m) => m.role == 'user');
    if (hasUserMessages) {
      final firstUserMsg = _messages.firstWhere((m) => m.role == 'user');
      // Avoid duplicating the same session we're about to load
      _chatHistory.insert(
        0,
        _ChatSession(
          title: firstUserMsg.content,
          createdAt: DateTime.now(),
          messages: List.from(_messages),
        ),
      );
    }

    final session = _chatHistory.removeAt(
      hasUserMessages ? historyIndex + 1 : historyIndex,
    );
    setState(() {
      _messages.clear();
      _messages.addAll(session.messages);
    });
  }

  void _showOptionsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          decoration: const BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppTheme.grey200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Option: Percakapan Baru
              _buildSheetOption(
                icon: Icons.add_comment_rounded,
                label: 'Percakapan Baru',
                color: AppTheme.primaryGreen,
                onTap: () {
                  Navigator.pop(ctx);
                  _startNewConversation();
                },
              ),
              const SizedBox(height: 8),
              // Option: Riwayat Percakapan
              _buildSheetOption(
                icon: Icons.history_rounded,
                label: 'Riwayat Percakapan',
                color: AppTheme.teal,
                badge: _chatHistory.isNotEmpty
                    ? '${_chatHistory.length}'
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  _showHistorySheet();
                },
              ),
              const SizedBox(height: 56),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSheetOption({
    required IconData icon,
    required String label,
    required Color color,
    String? badge,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.06),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.grey400,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHistorySheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          decoration: const BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.grey200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              Row(
                children: [
                  Icon(Icons.history_rounded, size: 18, color: AppTheme.teal),
                  const SizedBox(width: 8),
                  Text(
                    'Riwayat Percakapan',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  if (_chatHistory.isNotEmpty)
                    Text(
                      '${_chatHistory.length} sesi',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.grey400,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              // Empty state or history list
              if (_chatHistory.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 48,
                        color: AppTheme.grey200,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Belum ada riwayat',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Riwayat percakapan akan muncul\nketika Anda memulai percakapan baru',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.grey400,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _chatHistory.length,
                    itemBuilder: (context, index) {
                      final session = _chatHistory[index];
                      final msgCount = session.messages
                          .where((m) => m.role == 'user')
                          .length;
                      final timeAgo = _formatTimeAgo(session.createdAt);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              Navigator.pop(ctx);
                              _showSessionActionSheet(index);
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppTheme.bgColor,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppTheme.grey100,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppTheme.teal.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.chat_bubble_outline_rounded,
                                      size: 18,
                                      color: AppTheme.teal,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          session.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '$msgCount pesan · $timeAgo',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: AppTheme.grey400,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 14,
                                    color: AppTheme.grey400,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showSessionActionSheet(int historyIndex) {
    final session = _chatHistory[historyIndex];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          decoration: const BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.grey200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Session title preview
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.bgColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.grey100),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 16,
                      color: AppTheme.teal,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        session.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Option: Buka Percakapan
              _buildSheetOption(
                icon: Icons.open_in_new_rounded,
                label: 'Buka Percakapan',
                color: AppTheme.primaryGreen,
                onTap: () {
                  Navigator.pop(ctx);
                  _loadConversation(historyIndex);
                },
              ),
              const SizedBox(height: 8),
              // Option: Hapus Percakapan
              _buildSheetOption(
                icon: Icons.delete_outline_rounded,
                label: 'Hapus Percakapan',
                color: const Color(0xFFEF4444),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteConversation(historyIndex);
                },
              ),
              const SizedBox(height: 56),
            ],
          ),
        );
      },
    );
  }

  void _deleteConversation(int historyIndex) {
    setState(() {
      _chatHistory.removeAt(historyIndex);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Percakapan berhasil dihapus'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    return '${diff.inDays} hari lalu';
  }

  void _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    _msgController.clear();
    HapticFeedback.lightImpact();

    setState(() {
      _messages.add(LlmMessage(role: 'user', content: text));
      _isLoading = true;
    });

    try {
      final history = _messages.length > 10
          ? _messages.sublist(_messages.length - 10)
          : _messages;

      final responseText = await AlkaAiService.sendMessage(history);

      if (!mounted) return;
      setState(() {
        _messages.add(LlmMessage(role: 'assistant', content: responseText));
        _isLoading = false;
      });
      HapticFeedback.mediumImpact();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Terjadi kesalahan: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final int extraItems = _isLoading ? 1 : 0;
    final int totalItems = _messages.length + extraItems;

    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildWarningBanner(),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(20),
                physics: const BouncingScrollPhysics(),
                reverse: true,
                itemCount: totalItems,
                itemBuilder: (context, index) {
                  if (_isLoading && index == 0) {
                    return const _TypingDotsIndicator();
                  }

                  final msgIndex = _messages.length - 1 - (index - extraItems);
                  final msg = _messages[msgIndex];
                  final bool isRecent = msgIndex >= _messages.length - 2;

                  return _ChatBubbleAnimated(
                    key: ValueKey('msg_${msgIndex}_${msg.role}'),
                    msg: msg,
                    animate: isRecent,
                  );
                },
              ),
            ),
            _buildInputArea(),
          ],
        ),
      ),
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
                        const Icon(
                          Icons.auto_awesome_rounded,
                          size: 14,
                          color: AppTheme.teal,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Asisten Cerdas',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ALKA AI',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              // Three-dot menu button
              GestureDetector(
                onTap: _showOptionsSheet,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.grey100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.more_vert_rounded,
                    color: AppTheme.textSecondary,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWarningBanner() {
    return Container(
      width: double.infinity,
      color: AppTheme.softPurple.withOpacity(0.1),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: AppTheme.softPurple,
            size: 16,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'ALKA AI dapat berbuat kesalahan. Selalu periksa kembali informasi penting yang diberikan.',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.softPurple,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.white,
        border: Border.all(color: AppTheme.grey100, width: 1),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.grey100.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppTheme.grey200),
                  ),
                  child: TextField(
                    controller: _msgController,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textPrimary,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Tanya ALKA tentang SIJAWARA...',
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color: AppTheme.grey400,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _isLoading ? null : _sendMessage,
                child: Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    gradient: AppTheme.mainGradient,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.grey100, width: 1),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────
//  Animated Chat Bubble with NAV button support
// ───────────────────────────────────────────────

class _ChatBubbleAnimated extends StatefulWidget {
  final LlmMessage msg;
  final bool animate;

  const _ChatBubbleAnimated({
    super.key,
    required this.msg,
    required this.animate,
  });

  @override
  State<_ChatBubbleAnimated> createState() => _ChatBubbleAnimatedState();
}

class _ChatBubbleAnimatedState extends State<_ChatBubbleAnimated>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    final isUser = widget.msg.role == 'user';
    _slideAnim = Tween<Offset>(
      begin: Offset(isUser ? 0.15 : -0.15, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    if (widget.animate) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.msg.role == 'user';

    // Parse NAV marker for assistant messages
    final (cleanContent, navId) = isUser
        ? (widget.msg.content, null)
        : _parseNavMarker(widget.msg.content);

    // Lookup navigation action
    final navAction = navId != null ? _navActions[navId] : null;

    return SlideTransition(
      position: _slideAnim,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: Column(
          crossAxisAlignment: isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            // Chat bubble
            Align(
              alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.85,
                ),
                decoration: BoxDecoration(
                  color: isUser ? AppTheme.primaryGreen : AppTheme.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(isUser ? 20 : 4),
                    bottomRight: Radius.circular(isUser ? 4 : 20),
                  ),
                  border: Border.all(color: AppTheme.grey100, width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isUser)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.auto_awesome,
                                size: 12,
                                color: AppTheme.teal,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'ALKA AI',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.teal,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      MarkdownBody(
                        data: cleanContent,
                        styleSheet: MarkdownStyleSheet(
                          p: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: isUser ? Colors.white : AppTheme.textPrimary,
                            fontWeight: isUser
                                ? FontWeight.w500
                                : FontWeight.w400,
                          ),
                          strong: TextStyle(
                            color: isUser ? Colors.white : AppTheme.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                          code: TextStyle(
                            color: isUser ? Colors.white : AppTheme.softPurple,
                            backgroundColor: isUser
                                ? Colors.black.withOpacity(0.2)
                                : AppTheme.grey100,
                            fontWeight: FontWeight.w600,
                          ),
                          codeblockDecoration: BoxDecoration(
                            color: AppTheme.grey100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Navigation button (if AI included a [NAV:xxx] tag)
            if (navAction != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => navAction.pageBuilder(),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      gradient: AppTheme.mainGradient,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.grey100, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(navAction.icon, size: 16, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          navAction.label,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Spacing if no nav button
            if (navAction == null) const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────
//  Animated Typing Dots Indicator (3 bouncing dots)
// ───────────────────────────────────────────────

class _TypingDotsIndicator extends StatefulWidget {
  const _TypingDotsIndicator();

  @override
  State<_TypingDotsIndicator> createState() => _TypingDotsIndicatorState();
}

class _TypingDotsIndicatorState extends State<_TypingDotsIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(20),
          ),
          border: Border.all(color: AppTheme.grey100, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, size: 12, color: AppTheme.teal),
            const SizedBox(width: 8),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    final double phase = (_controller.value - i * 0.2) % 1.0;
                    final double bounce = (phase >= 0.0 && phase <= 0.4)
                        ? sin(phase / 0.4 * pi)
                        : 0.0;
                    return Padding(
                      padding: EdgeInsets.only(right: i < 2 ? 4 : 0),
                      child: Transform.translate(
                        offset: Offset(0, -bounce * 5),
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: AppTheme.teal.withOpacity(
                              0.4 + bounce * 0.6,
                            ),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
            const SizedBox(width: 8),
            Text(
              'ALKA mengetik',
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: AppTheme.grey400,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
