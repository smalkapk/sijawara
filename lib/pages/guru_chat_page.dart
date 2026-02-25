import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';

class GuruChatPage extends StatefulWidget {
  final String waliName;

  const GuruChatPage({super.key, required this.waliName});

  @override
  State<GuruChatPage> createState() => _GuruChatPageState();
}

class _GuruChatPageState extends State<GuruChatPage> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocus = FocusNode();

  final List<Map<String, dynamic>> _messages = [
    {
      'text': 'Assalamu\'alaikum Bapak guru, maaf mengganggu waktunya.',
      'isMe': false,
      'time': '09:00',
      'status': 'read',
    },
    {
      'text': 'Wa\'alaikumussalam. Iya Bapak/Ibu, ada yang bisa saya bantu?',
      'isMe': true,
      'time': '09:05',
      'status': 'read',
    },
    {
      'text': 'Apakah besok anak-anak ada jadwal membawa buku gambar?',
      'isMe': false,
      'time': '09:10',
      'status': 'read',
    },
    {
      'text':
          'Iya betul, besok ada pelajaran seni rupa. Jadi anak-anak diminta membawa buku gambar dan pensil warna ya.',
      'isMe': true,
      'time': '09:12',
      'status': 'read',
    },
    {
      'text':
          'Baik Pak, terima kasih informasinya. Nanti saya siapkan peralatan anak saya.',
      'isMe': false,
      'time': '09:15',
      'status': 'read',
    },
  ];

  String get _initials {
    final parts = widget.waliName.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  void _sendMessage() {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({
        'text': text,
        'isMe': true,
        'time': _getCurrentTime(),
        'status': 'sent',
      });
      _msgController.clear();
    });

    // Scroll to bottom
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    HapticFeedback.lightImpact();
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: const Color(0xFFECE5DD),
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: Container(
                // WhatsApp chat background pattern
                decoration: const BoxDecoration(
                  color: Color(0xFFECE5DD),
                ),
                child: ListView.builder(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final showDate = index == 0;
                    return Column(
                      children: [
                        if (showDate) _buildDateChip('Hari ini'),
                        _buildMessageBubble(_messages[index]),
                      ],
                    );
                  },
                ),
              ),
            ),
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 16, 12),
      child: SafeArea(
        bottom: false,
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
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: AppTheme.primaryGreen,
                    size: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Avatar
            CircleAvatar(
              radius: 20,
              backgroundColor: AppTheme.primaryGreen.withOpacity(0.12),
              child: Text(
                _initials,
                style: const TextStyle(
                  color: AppTheme.primaryGreen,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Name + status
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.waliName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF25D366),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Online',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Three-dot menu
            IconButton(
              icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textSecondary),
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateChip(String date) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE1F2FB),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        date,
        style: const TextStyle(
          color: Color(0xFF5A7A84),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    final isMe = msg['isMe'] as bool;
    final status = msg['status'] as String;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 3),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        child: CustomPaint(
          painter: _BubbleTailPainter(
            isMe: isMe,
            color: isMe ? const Color(0xFFDCF8C6) : Colors.white,
          ),
          child: Container(
            padding: EdgeInsets.fromLTRB(
              isMe ? 10 : 16,
              8,
              isMe ? 16 : 10,
              8,
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
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Message text
                Padding(
                  padding: const EdgeInsets.only(right: 48),
                  child: Text(
                    msg['text'],
                    style: const TextStyle(
                      color: Color(0xFF303030),
                      fontSize: 15,
                      height: 1.35,
                    ),
                  ),
                ),
                // Time + status
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      msg['time'],
                      style: TextStyle(
                        color: isMe
                            ? const Color(0xFF6D9B78)
                            : const Color(0xFF9BA5A5),
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      Icon(
                        status == 'read'
                            ? Icons.done_all_rounded
                            : status == 'delivered'
                                ? Icons.done_all_rounded
                                : Icons.done_rounded,
                        size: 16,
                        color: status == 'read'
                            ? const Color(0xFF53BDEB)
                            : const Color(0xFF8FAE96),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      color: const Color(0xFFF0F0F0),
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Message input field
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Emoji button
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 4),
                      child: IconButton(
                        icon: const Icon(Icons.emoji_emotions_outlined,
                            color: Color(0xFF8696A0), size: 24),
                        onPressed: () {},
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 40, minHeight: 40),
                      ),
                    ),
                    // Text field
                    Expanded(
                      child: TextField(
                        controller: _msgController,
                        focusNode: _inputFocus,
                        decoration: const InputDecoration(
                          hintText: 'Ketik pesan',
                          hintStyle: TextStyle(
                            color: Color(0xFF8696A0),
                            fontSize: 16,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding:
                              EdgeInsets.symmetric(vertical: 12, horizontal: 0),
                        ),
                        style: const TextStyle(fontSize: 16),
                        textCapitalization: TextCapitalization.sentences,
                        maxLines: 5,
                        minLines: 1,
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    // Attach button
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: IconButton(
                        icon: Transform.rotate(
                          angle: 0.7,
                          child: const Icon(Icons.attach_file_rounded,
                              color: Color(0xFF8696A0), size: 24),
                        ),
                        onPressed: () {},
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 40, minHeight: 40),
                      ),
                    ),
                    // Camera button (when text is empty)
                    if (_msgController.text.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 4, bottom: 4),
                        child: IconButton(
                          icon: const Icon(Icons.camera_alt_rounded,
                              color: Color(0xFF8696A0), size: 24),
                          onPressed: () {},
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 40, minHeight: 40),
                        ),
                      ),
                    if (_msgController.text.isNotEmpty)
                      const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Send / Mic button
            GestureDetector(
              onTap: _msgController.text.isNotEmpty ? _sendMessage : null,
              child: Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: AppTheme.primaryGreen,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _msgController.text.isNotEmpty
                      ? Icons.send_rounded
                      : Icons.mic_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter for WhatsApp-style bubble tail
class _BubbleTailPainter extends CustomPainter {
  final bool isMe;
  final Color color;

  _BubbleTailPainter({required this.isMe, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    // Tail is drawn by the border radius asymmetry, no custom paint needed
    // This is a no-op painter kept as placeholder for future tail enhancement
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
