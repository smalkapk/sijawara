import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../theme.dart';
import '../services/chat_service.dart';
import '../widgets/chat_attachments.dart';

/// Halaman chat Wali → Guru Kelas
/// Langsung masuk ke chat (tanpa daftar kontak), karena wali hanya
/// bisa chat dengan guru kelas anaknya.
class WaliDiskusiGuruPage extends StatefulWidget {
  const WaliDiskusiGuruPage({super.key});

  @override
  State<WaliDiskusiGuruPage> createState() => _WaliDiskusiGuruPageState();
}

class _WaliDiskusiGuruPageState extends State<WaliDiskusiGuruPage> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocus = FocusNode();

  GuruKelasInfo? _guruInfo;
  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _isUploading = false;
  bool _isPartnerTyping = false;
  int _currentUserId = 0;

  // WebSocket
  ChatWebSocket? _ws;
  StreamSubscription<Map<String, dynamic>>? _wsSub;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      _currentUserId = await ChatService.getCurrentUserId();

      final guruInfo = await ChatService.getGuruInfo();
      if (!mounted) return;
      setState(() => _guruInfo = guruInfo);

      final messages =
          await ChatService.getHistory(partnerId: guruInfo.guruId);
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _isLoading = false;
      });

      _scrollToBottom();
      ChatService.markReadHttp(partnerId: guruInfo.guruId);
      _connectWebSocket();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      debugPrint('Gagal init chat wali: $e');
    }
  }

  void _connectWebSocket() {
    _ws = ChatWebSocket();
    _wsSub = _ws!.messageStream.listen(_handleWsMessage);
    _ws!.connect();
  }

  void _handleWsMessage(Map<String, dynamic> data) {
    final type = data['type'] as String?;

    switch (type) {
      case 'new_message':
        final msgData = data['data'] as Map<String, dynamic>;
        final senderId = msgData['sender_id'] is int
            ? msgData['sender_id']
            : int.parse(msgData['sender_id'].toString());

        if (_guruInfo == null) return;
        if (senderId != _currentUserId && senderId != _guruInfo!.guruId) {
          return;
        }

        final msg = ChatMessage(
          id: msgData['id'] is int
              ? msgData['id']
              : int.parse(msgData['id'].toString()),
          senderId: senderId,
          receiverId: msgData['receiver_id'] is int
              ? msgData['receiver_id']
              : int.parse(msgData['receiver_id'].toString()),
          message: msgData['message'] as String? ?? '',
          isMe: senderId == _currentUserId,
          isRead: msgData['is_read'] == true,
          createdAt: DateTime.tryParse(msgData['created_at'] ?? '') ??
              DateTime.now(),
          attachmentType:
              ChatMessage.parseAttachType(msgData['attachment_type']),
          attachmentUrl: msgData['attachment_url'] as String?,
          attachmentName: msgData['attachment_name'] as String?,
          attachmentSize: msgData['attachment_size'] != null
              ? (msgData['attachment_size'] is int
                  ? msgData['attachment_size']
                  : int.tryParse(msgData['attachment_size'].toString()))
              : null,
        );

        if (_messages.any((m) => m.id == msg.id)) return;

        if (mounted) {
          setState(() => _messages.add(msg));
          _scrollToBottom();
          if (!msg.isMe) {
            _ws?.markRead(partnerId: _guruInfo!.guruId);
          }
        }
        break;

      case 'messages_read':
        if (mounted) {
          setState(() {
            _messages = _messages
                .map((m) => m.isMe ? m.copyWith(isRead: true) : m)
                .toList();
          });
        }
        break;

      case 'typing':
        final typingData = data['data'] as Map<String, dynamic>;
        if (mounted) {
          setState(
              () => _isPartnerTyping = typingData['is_typing'] == true);
        }
        break;
    }
  }

  void _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty || _guruInfo == null || _isSending) return;

    _msgController.clear();
    HapticFeedback.lightImpact();
    setState(() {});

    if (_ws != null && _ws!.isConnected) {
      _ws!.sendMessage(receiverId: _guruInfo!.guruId, message: text);
    } else {
      setState(() => _isSending = true);
      try {
        final msg = await ChatService.sendMessageHttp(
          receiverId: _guruInfo!.guruId,
          message: text,
        );
        if (mounted) {
          setState(() {
            if (!_messages.any((m) => m.id == msg.id)) _messages.add(msg);
            _isSending = false;
          });
          _scrollToBottom();
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isSending = false);
          _showError('Gagal kirim: $e');
        }
      }
    }
  }

  Future<void> _sendAttachment(File file, String type) async {
    if (_guruInfo == null || _isUploading) return;

    setState(() => _isUploading = true);
    try {
      final msg = await ChatService.uploadAttachment(
        receiverId: _guruInfo!.guruId,
        file: file,
        attachmentType: type,
      );
      if (mounted) {
        setState(() {
          if (!_messages.any((m) => m.id == msg.id)) _messages.add(msg);
          _isUploading = false;
        });
        _scrollToBottom();

        // Notify receiver via WS (broadcast only, no DB insert)
        if (_ws != null && _ws!.isConnected) {
          _ws!.notifyAttachment(
            id: msg.id,
            receiverId: _guruInfo!.guruId,
            message: msg.message,
            attachmentType: type,
            attachmentUrl: msg.attachmentUrl,
            attachmentName: msg.attachmentName,
            attachmentSize: msg.attachmentSize,
            createdAt: msg.createdAt.toIso8601String(),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        _showError('Gagal upload: $e');
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateGroupLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDate = DateTime(dt.year, dt.month, dt.day);

    if (msgDate == today) return 'Hari ini';
    if (msgDate == today.subtract(const Duration(days: 1))) return 'Kemarin';
    return DateFormat('d MMMM yyyy', 'id_ID').format(dt);
  }

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    _inputFocus.dispose();
    _wsSub?.cancel();
    _ws?.dispose();
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
              child: _isLoading
                  ? _buildLoadingState()
                  : _guruInfo == null
                      ? _buildErrorState()
                      : _buildChatArea(),
            ),
            if (_guruInfo != null) _buildMessageInput(),
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
                  child: const Icon(Icons.arrow_back_rounded,
                      color: AppTheme.primaryGreen, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 14),
            CircleAvatar(
              radius: 20,
              backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.12),
              child: Text(
                _guruInfo != null ? _getInitials(_guruInfo!.guruName) : '?',
                style: const TextStyle(
                    color: AppTheme.primaryGreen,
                    fontWeight: FontWeight.w700,
                    fontSize: 14),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _guruInfo?.guruName ?? 'Guru Kelas',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  if (_isPartnerTyping)
                    Text('Sedang mengetik...',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.primaryGreen,
                            fontStyle: FontStyle.italic))
                  else
                    Text(
                      _guruInfo != null
                          ? 'Guru Kelas ${_guruInfo!.className}'
                          : '',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.grey400),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.more_vert_rounded,
                  color: AppTheme.textSecondary),
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
                strokeWidth: 3, color: AppTheme.primaryGreen),
          ),
          const SizedBox(height: 16),
          Text('Memuat percakapan...',
              style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.grey400,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
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
              child: Icon(Icons.chat_bubble_outline_rounded,
                  size: 56,
                  color: AppTheme.primaryGreen.withValues(alpha: 0.4)),
            ),
            const SizedBox(height: 24),
            Text('Tidak Dapat Terhubung',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            Text(
              'Pastikan anak Anda sudah terdaftar\ndi kelas yang memiliki guru kelas',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14, color: AppTheme.grey400, height: 1.5),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: () {
                setState(() => _isLoading = true);
                _init();
              },
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
                    Text('Coba Lagi',
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

  Widget _buildChatArea() {
    if (_messages.isEmpty) return _buildEmptyChat();

    return Stack(
      children: [
        ListView.builder(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          itemCount: _messages.length,
          itemBuilder: (context, index) {
            final msg = _messages[index];
            final showDate = index == 0 ||
                !_isSameDate(_messages[index - 1].createdAt, msg.createdAt);
            return Column(
              children: [
                if (showDate)
                  _buildDateChip(_formatDateGroupLabel(msg.createdAt)),
                _buildMessageBubble(msg),
              ],
            );
          },
        ),
        if (_isUploading)
          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    ),
                    SizedBox(width: 10),
                    Text('Mengirim...',
                        style: TextStyle(color: Colors.white, fontSize: 13)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyChat() {
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
              child: Icon(Icons.forum_rounded,
                  size: 56,
                  color: AppTheme.primaryGreen.withValues(alpha: 0.4)),
            ),
            const SizedBox(height: 24),
            Text('Mulai Percakapan',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            Text(
              'Kirim pesan kepada ${_guruInfo?.guruName ?? 'Guru Kelas'}\nuntuk memulai diskusi',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14, color: AppTheme.grey400, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _buildDateChip(String date) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE1F2FB),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1)),
        ],
      ),
      child: Text(date,
          style: const TextStyle(
              color: Color(0xFF5A7A84),
              fontSize: 12,
              fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    // Image bubble
    if (msg.isImage) {
      return ImageMessageBubble(msg: msg, formatTime: _formatTime);
    }
    // Document bubble
    if (msg.isDocument) {
      return DocumentMessageBubble(msg: msg, formatTime: _formatTime);
    }
    // Text bubble
    return _buildTextBubble(msg);
  }

  Widget _buildTextBubble(ChatMessage msg) {
    final isMe = msg.isMe;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 3),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78),
        child: Container(
          padding: EdgeInsets.fromLTRB(
              isMe ? 10 : 16, 8, isMe ? 16 : 10, 8),
          decoration: BoxDecoration(
            color: isMe ? const Color(0xFFDCF8C6) : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(8),
              topRight: const Radius.circular(8),
              bottomLeft: isMe
                  ? const Radius.circular(8)
                  : const Radius.circular(0),
              bottomRight: isMe
                  ? const Radius.circular(0)
                  : const Radius.circular(8),
            ),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 2,
                  offset: const Offset(0, 1)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 48),
                child: Text(msg.message,
                    style: const TextStyle(
                        color: Color(0xFF303030),
                        fontSize: 15,
                        height: 1.35)),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_formatTime(msg.createdAt),
                      style: TextStyle(
                          color: isMe
                              ? const Color(0xFF6D9B78)
                              : const Color(0xFF9BA5A5),
                          fontSize: 11,
                          fontWeight: FontWeight.w400)),
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
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 1)),
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
                        onPressed: () {
                          _inputFocus.unfocus();
                          ChatEmojiPicker.show(
                            context,
                            controller: _msgController,
                            onEmojiSelected: () => setState(() {}),
                          );
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                            minWidth: 40, minHeight: 40),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _msgController,
                        focusNode: _inputFocus,
                        decoration: const InputDecoration(
                          hintText: 'Ketik pesan',
                          hintStyle: TextStyle(
                              color: Color(0xFF8696A0), fontSize: 16),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                              vertical: 12, horizontal: 0),
                        ),
                        style: const TextStyle(fontSize: 16),
                        textCapitalization: TextCapitalization.sentences,
                        maxLines: 5,
                        minLines: 1,
                        onChanged: (_) {
                          setState(() {});
                          if (_guruInfo != null && _ws != null) {
                            _ws!.sendTyping(
                              partnerId: _guruInfo!.guruId,
                              isTyping: _msgController.text.isNotEmpty,
                            );
                          }
                        },
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    // Attachment button
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: IconButton(
                        icon: Transform.rotate(
                          angle: 0.7,
                          child: const Icon(Icons.attach_file_rounded,
                              color: Color(0xFF8696A0), size: 24),
                        ),
                        onPressed: () {
                          ChatAttachmentPicker.show(
                            context,
                            onFilePicked: _sendAttachment,
                          );
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                            minWidth: 40, minHeight: 40),
                      ),
                    ),
                    // Camera button (when no text)
                    if (_msgController.text.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 4, bottom: 4),
                        child: IconButton(
                          icon: const Icon(Icons.camera_alt_rounded,
                              color: Color(0xFF8696A0), size: 24),
                          onPressed: () {
                            ChatCameraPicker.show(
                              context,
                              onPhotoTaken: (file) =>
                                  _sendAttachment(file, 'image'),
                            );
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                              minWidth: 40, minHeight: 40),
                        ),
                      ),
                    if (_msgController.text.isNotEmpty)
                      const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
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

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return parts[0][0].toUpperCase();
  }
}
