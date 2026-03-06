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
  ChatMessage? _replyingTo;
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
            replyToMessageId: msgData['reply_to_message_id'] != null
              ? (msgData['reply_to_message_id'] is int
                ? msgData['reply_to_message_id']
                : int.tryParse(msgData['reply_to_message_id'].toString()))
              : null,
            replyPreview: msgData['reply_preview'] as String?,
            replySenderId: msgData['reply_sender_id'] != null
              ? (msgData['reply_sender_id'] is int
                ? msgData['reply_sender_id']
                : int.tryParse(msgData['reply_sender_id'].toString()))
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

      case 'message_deleted':
        final deletedData = data['data'] as Map<String, dynamic>;
        final deletedId = deletedData['message_id'] is int
            ? deletedData['message_id'] as int
            : int.tryParse(deletedData['message_id'].toString()) ?? -1;
        if (mounted && deletedId != -1) {
          setState(() {
            _messages = _messages
                .map((m) => m.id == deletedId ? m.copyWith(message: 'deleted') : m)
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

    final replyingTo = _replyingTo;
    _msgController.clear();
    HapticFeedback.lightImpact();
    setState(() => _replyingTo = null);

    if (_ws != null && _ws!.isConnected) {
      _ws!.sendMessage(
        receiverId: _guruInfo!.guruId,
        message: text,
        replyToMessageId: replyingTo?.id,
      );
    } else {
      setState(() => _isSending = true);
      try {
        final msg = await ChatService.sendMessageHttp(
          receiverId: _guruInfo!.guruId,
          message: text,
          replyToMessageId: replyingTo?.id,
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

    final replyingTo = _replyingTo;
    setState(() => _replyingTo = null);

    setState(() => _isUploading = true);
    try {
      final msg = await ChatService.uploadAttachment(
        receiverId: _guruInfo!.guruId,
        file: file,
        attachmentType: type,
        replyToMessageId: replyingTo?.id,
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
            replyToMessageId: msg.replyToMessageId,
            replyPreview: msg.replyPreview,
            replySenderId: msg.replySenderId,
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
    Widget bubble;
    if (msg.isImage) {
      bubble = ImageMessageBubble(msg: msg, formatTime: _formatTime);
    } else if (msg.isDocument) {
      bubble = DocumentMessageBubble(msg: msg, formatTime: _formatTime);
    } else {
      bubble = _buildTextBubble(msg);
    }

    return _ReplySwipeBubble(
      key: ValueKey('swipe_${msg.id}'),
      onReply: () {
        setState(() => _replyingTo = msg);
        _inputFocus.requestFocus();
      },
      onLongPress: () => _showMessageOptions(msg),
      child: bubble,
    );
  }

  void _showMessageOptions(ChatMessage msg) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _MessageOptionsSheet(
        msg: msg,
        partnerName: _guruInfo?.guruName ?? 'Guru Kelas',
        onReply: () {
          Navigator.pop(context);
          setState(() => _replyingTo = msg);
          _inputFocus.requestFocus();
        },
        onDelete: msg.isMe
            ? () async {
                Navigator.pop(context);
                try {
                  await ChatService.deleteMessage(messageId: msg.id);
                  if (mounted) {
                    setState(() {
                      _messages = _messages
                          .map((m) => m.id == msg.id
                              ? m.copyWith(message: 'deleted')
                              : m)
                          .toList();
                    });
                  }
                  // Broadcast ke partner via WS
                  _ws?.deleteMessageWs(
                    messageId: msg.id,
                    receiverId: _guruInfo!.guruId,
                  );
                } catch (e) {
                  if (mounted) _showError('Gagal menghapus: $e');
                }
              }
            : null,
        onPin: () {
          Navigator.pop(context);
          // TODO: implementasi pin pesan
        },
        onDetail: () {
          Navigator.pop(context);
          // TODO: implementasi detail pesan
        },
      ),
    );
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
              if (msg.replyToMessageId != null && msg.message != 'deleted')
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isMe
                        ? AppTheme.primaryGreen.withValues(alpha: 0.10)
                        : const Color(0xFFF1F1F1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border(
                      left: BorderSide(
                        color: isMe ? AppTheme.primaryGreen : AppTheme.grey400,
                        width: 3,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        msg.replySenderId == _currentUserId
                            ? 'Anda'
                            : (_guruInfo?.guruName ?? 'Guru Kelas'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isMe ? AppTheme.primaryGreen : AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        (msg.replyPreview == null || msg.replyPreview!.trim().isEmpty)
                            ? 'Pesan'
                            : msg.replyPreview!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(right: 48),
                child: msg.message == 'deleted'
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.block_rounded,
                              size: 14,
                              color: const Color(0xFF9BA5A5).withValues(alpha: 0.8)),
                          const SizedBox(width: 5),
                          Text(
                            'Pesan telah dihapus',
                            style: TextStyle(
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                              color: const Color(0xFF9BA5A5).withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      )
                    : Text(msg.message,
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, animation) {
                final offset = Tween<Offset>(
                  begin: const Offset(0, 0.2),
                  end: Offset.zero,
                ).animate(animation);
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(position: offset, child: child),
                );
              },
              child: _replyingTo == null
                  ? const SizedBox.shrink()
                  : Container(
                      key: ValueKey('reply_box_${_replyingTo!.id}'),
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.grey100, width: 1),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 3,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _replyingTo!.isMe
                                      ? 'Membalas Anda'
                                      : 'Membalas ${_guruInfo?.guruName ?? 'Guru'}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primaryGreen,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _replyingTo!.isImage
                                      ? '📷 Foto'
                                      : (_replyingTo!.isDocument
                                          ? '📄 Dokumen'
                                          : (_replyingTo!.message.trim().isEmpty
                                              ? 'Pesan'
                                              : _replyingTo!.message)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setState(() => _replyingTo = null),
                            child: const Icon(
                              Icons.close_rounded,
                              color: AppTheme.grey400,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            Row(
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

class _ReplySwipeBubble extends StatefulWidget {
  final Widget child;
  final VoidCallback onReply;
  final VoidCallback? onLongPress;

  const _ReplySwipeBubble({
    super.key,
    required this.child,
    required this.onReply,
    this.onLongPress,
  });

  @override
  State<_ReplySwipeBubble> createState() => _ReplySwipeBubbleState();
}

class _ReplySwipeBubbleState extends State<_ReplySwipeBubble>
    with SingleTickerProviderStateMixin {
  static const double _threshold = 70.0;
  static const double _maxDrag = 82.0;

  double _dragOffset = 0.0;
  bool _triggered = false;

  late AnimationController _pressAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(parent: _pressAnim, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_dragOffset / _threshold).clamp(0.0, 1.0);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPressStart: (_) => _pressAnim.forward(),
      onLongPress: () {
        HapticFeedback.lightImpact();
        widget.onLongPress?.call();
        _pressAnim.reverse();
      },
      onLongPressEnd: (_) => _pressAnim.reverse(),
      onLongPressCancel: () => _pressAnim.reverse(),
      onHorizontalDragUpdate: (d) {
        if (d.delta.dx > 0) {
          final next = (_dragOffset + d.delta.dx).clamp(0.0, _maxDrag);
          if (!_triggered && next >= _threshold) {
            _triggered = true;
            HapticFeedback.mediumImpact();
          }
          setState(() => _dragOffset = next);
        } else {
          setState(() => _dragOffset =
              (_dragOffset + d.delta.dx).clamp(0.0, _maxDrag));
        }
      },
      onHorizontalDragEnd: (_) {
        if (_triggered) widget.onReply();
        setState(() {
          _dragOffset = 0.0;
          _triggered = false;
        });
      },
      onHorizontalDragCancel: () {
        setState(() {
          _dragOffset = 0.0;
          _triggered = false;
        });
      },
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: _dragOffset == 0
                  ? const Duration(milliseconds: 250)
                  : Duration.zero,
              curve: Curves.elasticOut,
              transform: Matrix4.translationValues(_dragOffset, 0, 0),
              child: widget.child,
            ),
            if (_dragOffset > 6)
              Positioned(
                left: 4,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Opacity(
                    opacity: progress,
                    child: Transform.scale(
                      scale: 0.6 + (progress * 0.4),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.reply_rounded,
                          color: AppTheme.primaryGreen,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Bottom sheet opsi pesan
// ──────────────────────────────────────────────
class _MessageOptionsSheet extends StatelessWidget {
  final ChatMessage msg;
  final String partnerName;
  final VoidCallback onReply;
  final VoidCallback? onDelete;
  final VoidCallback onPin;
  final VoidCallback onDetail;

  const _MessageOptionsSheet({
    required this.msg,
    required this.partnerName,
    required this.onReply,
    this.onDelete,
    required this.onPin,
    required this.onDetail,
  });

  @override
  Widget build(BuildContext context) {
    final previewText = msg.isImage
        ? '📷 Foto'
        : msg.isDocument
            ? '📄 ${msg.attachmentName ?? 'Dokumen'}'
            : msg.message.trim().isEmpty
                ? 'Pesan'
                : msg.message;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 16),
            decoration: BoxDecoration(
              color: AppTheme.grey100,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Preview pesan
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.offWhite,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.grey100),
            ),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        msg.isMe ? 'Anda' : partnerName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        previewText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w400,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, thickness: 1, indent: 20, endIndent: 20),
          const SizedBox(height: 4),

          // Opsi: Balas
          _OptionTile(
            icon: Icons.reply_rounded,
            iconColor: AppTheme.primaryGreen,
            label: 'Balas Pesan',
            onTap: onReply,
          ),

          // Opsi: Hapus (hanya jika pesan sendiri)
          if (onDelete != null)
            _OptionTile(
              icon: Icons.delete_outline_rounded,
              iconColor: Colors.red,
              label: 'Hapus Pesan',
              labelColor: Colors.red,
              onTap: onDelete!,
            ),

          // Opsi: Pin
          _OptionTile(
            icon: Icons.push_pin_outlined,
            iconColor: AppTheme.textSecondary,
            label: 'Pin Pesan',
            onTap: onPin,
          ),

          // Opsi: Detail
          _OptionTile(
            icon: Icons.info_outline_rounded,
            iconColor: AppTheme.textSecondary,
            label: 'Detail Pesan',
            onTap: onDetail,
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final Color? labelColor;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.labelColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: labelColor ?? AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
