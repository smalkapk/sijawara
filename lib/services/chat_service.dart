import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

/// Tipe lampiran
enum AttachmentType { none, image, document }

/// Model pesan chat
class ChatMessage {
  final int id;
  final int senderId;
  final int receiverId;
  final String message;
  final bool isMe;
  final bool isRead;
  final DateTime createdAt;
  final AttachmentType attachmentType;
  final String? attachmentUrl;
  final String? attachmentName;
  final int? attachmentSize;
  final int? replyToMessageId;
  final String? replyPreview;
  final int? replySenderId;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.message,
    required this.isMe,
    required this.isRead,
    required this.createdAt,
    this.attachmentType = AttachmentType.none,
    this.attachmentUrl,
    this.attachmentName,
    this.attachmentSize,
    this.replyToMessageId,
    this.replyPreview,
    this.replySenderId,
  });

  bool get hasAttachment => attachmentType != AttachmentType.none;
  bool get isImage => attachmentType == AttachmentType.image;
  bool get isDocument => attachmentType == AttachmentType.document;

  /// Ukuran file dalam format readable
  String get fileSizeFormatted {
    if (attachmentSize == null) return '';
    if (attachmentSize! < 1024) return '${attachmentSize}B';
    if (attachmentSize! < 1024 * 1024) {
      return '${(attachmentSize! / 1024).toStringAsFixed(1)}KB';
    }
    return '${(attachmentSize! / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  /// Ekstensi file
  String get fileExtension {
    if (attachmentName == null) return '';
    final parts = attachmentName!.split('.');
    return parts.length > 1 ? parts.last.toUpperCase() : '';
  }

  static AttachmentType parseAttachType(dynamic val) {
    if (val == null || val == 'none') return AttachmentType.none;
    if (val == 'image') return AttachmentType.image;
    if (val == 'document') return AttachmentType.document;
    return AttachmentType.none;
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      senderId: json['sender_id'] is int
          ? json['sender_id']
          : int.parse(json['sender_id'].toString()),
      receiverId: json['receiver_id'] is int
          ? json['receiver_id']
          : int.parse(json['receiver_id'].toString()),
      message: json['message'] as String? ?? '',
      isMe: json['is_me'] == true,
      isRead: json['is_read'] == true || json['is_read'] == 1,
      createdAt: DateTime.parse(json['created_at'] as String),
      attachmentType: parseAttachType(json['attachment_type']),
      attachmentUrl: json['attachment_url'] as String?,
      attachmentName: json['attachment_name'] as String?,
      attachmentSize: json['attachment_size'] != null
          ? (json['attachment_size'] is int
                ? json['attachment_size']
                : int.tryParse(json['attachment_size'].toString()))
          : null,
      replyToMessageId: json['reply_to_message_id'] != null
          ? (json['reply_to_message_id'] is int
                ? json['reply_to_message_id']
                : int.tryParse(json['reply_to_message_id'].toString()))
          : null,
      replyPreview: json['reply_preview'] as String?,
      replySenderId: json['reply_sender_id'] != null
          ? (json['reply_sender_id'] is int
                ? json['reply_sender_id']
                : int.tryParse(json['reply_sender_id'].toString()))
          : null,
    );
  }

  ChatMessage copyWith({bool? isRead, String? message}) {
    return ChatMessage(
      id: id,
      senderId: senderId,
      receiverId: receiverId,
      message: message ?? this.message,
      isMe: isMe,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      attachmentType: attachmentType,
      attachmentUrl: attachmentUrl,
      attachmentName: attachmentName,
      attachmentSize: attachmentSize,
      replyToMessageId: replyToMessageId,
      replyPreview: replyPreview,
      replySenderId: replySenderId,
    );
  }
}

/// Model info guru kelas (untuk wali)
class GuruKelasInfo {
  final int guruId;
  final String guruName;
  final String? guruAvatar;
  final String className;
  final List<String> children;

  GuruKelasInfo({
    required this.guruId,
    required this.guruName,
    this.guruAvatar,
    required this.className,
    required this.children,
  });

  factory GuruKelasInfo.fromJson(Map<String, dynamic> json) {
    return GuruKelasInfo(
      guruId: json['guru_id'] is int
          ? json['guru_id']
          : int.parse(json['guru_id'].toString()),
      guruName: json['guru_name'] as String? ?? '',
      guruAvatar: json['guru_avatar'] as String?,
      className: json['class_name'] as String? ?? '',
      children:
          (json['children'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}

/// Model kontak wali (untuk guru)
class WaliContact {
  final int waliId;
  final String waliName;
  final String? avatarUrl;
  final String childrenNames;
  final String className;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final bool lastMessageIsMe;
  final int unreadCount;

  WaliContact({
    required this.waliId,
    required this.waliName,
    this.avatarUrl,
    required this.childrenNames,
    required this.className,
    this.lastMessage,
    this.lastMessageTime,
    required this.lastMessageIsMe,
    required this.unreadCount,
  });

  factory WaliContact.fromJson(Map<String, dynamic> json) {
    return WaliContact(
      waliId: json['wali_id'] is int
          ? json['wali_id']
          : int.parse(json['wali_id'].toString()),
      waliName: json['wali_name'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
      childrenNames: json['children_names'] as String? ?? '',
      className: json['class_name'] as String? ?? '',
      lastMessage: json['last_message'] as String?,
      lastMessageTime: json['last_message_time'] != null
          ? DateTime.tryParse(json['last_message_time'] as String)
          : null,
      lastMessageIsMe: json['last_message_is_me'] == true,
      unreadCount: json['unread_count'] is int
          ? json['unread_count']
          : int.tryParse(json['unread_count']?.toString() ?? '0') ?? 0,
    );
  }

  String get initials {
    final parts = waliName.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts.isNotEmpty ? parts[0][0].toUpperCase() : '?';
  }
}

/// Service utama untuk fitur chat
class ChatService {
  static const String _baseUrl = 'https://portal-smalka.com/api';
  static const String _wsUrl = 'wss://portal-smalka.com/ws';

  // ── HTTP API Methods ──

  /// Wali: Ambil info guru kelas
  static Future<GuruKelasInfo> getGuruInfo() async {
    final token = await AuthService.getToken();
    final response = await http
        .get(
          Uri.parse('$_baseUrl/chat.php?action=guru_info'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        )
        .timeout(const Duration(seconds: 15));

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['success'] == true) {
      return GuruKelasInfo.fromJson(body['data'] as Map<String, dynamic>);
    }
    final debugInfo = body['debug'];
    final msg = body['message'] ?? 'Gagal mendapatkan info guru';
    throw Exception(debugInfo != null ? '$msg ($debugInfo)' : msg);
  }

  /// Guru: Ambil daftar kontak wali
  static Future<List<WaliContact>> getContacts() async {
    final token = await AuthService.getToken();
    final response = await http
        .get(
          Uri.parse('$_baseUrl/chat.php?action=contacts'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        )
        .timeout(const Duration(seconds: 15));

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['success'] == true) {
      final list = body['data'] as List<dynamic>;
      return list
          .map((e) => WaliContact.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    final debugInfo = body['debug'];
    final msg = body['message'] ?? 'Gagal mendapatkan kontak';
    throw Exception(debugInfo != null ? '$msg ($debugInfo)' : msg);
  }

  /// Ambil riwayat chat
  static Future<List<ChatMessage>> getHistory({
    required int partnerId,
    int limit = 50,
    int? beforeId,
  }) async {
    final token = await AuthService.getToken();
    String url =
        '$_baseUrl/chat.php?action=history&partner_id=$partnerId&limit=$limit';
    if (beforeId != null) {
      url += '&before_id=$beforeId';
    }

    final response = await http
        .get(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        )
        .timeout(const Duration(seconds: 15));

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['success'] == true) {
      final list = body['data'] as List<dynamic>;
      return list
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    final debugInfo = body['debug'];
    final msg = body['message'] ?? 'Gagal mendapatkan riwayat chat';
    throw Exception(debugInfo != null ? '$msg ($debugInfo)' : msg);
  }

  /// Kirim pesan via HTTP (fallback)
  static Future<ChatMessage> sendMessageHttp({
    required int receiverId,
    required String message,
    int? replyToMessageId,
  }) async {
    final token = await AuthService.getToken();
    final response = await http
        .post(
          Uri.parse('$_baseUrl/chat.php?action=send'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'receiver_id': receiverId,
            'message': message,
            if (replyToMessageId != null)
              'reply_to_message_id': replyToMessageId,
          }),
        )
        .timeout(const Duration(seconds: 15));

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['success'] == true) {
      return ChatMessage.fromJson(body['data'] as Map<String, dynamic>);
    }
    throw Exception(body['message'] ?? 'Gagal mengirim pesan');
  }

  /// Upload file/gambar + kirim pesan
  static Future<ChatMessage> uploadAttachment({
    required int receiverId,
    required File file,
    required String attachmentType, // 'image' atau 'document'
    String message = '',
    int? replyToMessageId,
  }) async {
    final token = await AuthService.getToken();
    final uri = Uri.parse('$_baseUrl/chat.php?action=upload');

    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['receiver_id'] = receiverId.toString();
    request.fields['message'] = message;
    request.fields['attachment_type'] = attachmentType;
    if (replyToMessageId != null) {
      request.fields['reply_to_message_id'] = replyToMessageId.toString();
    }
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 60),
    );
    final response = await http.Response.fromStream(streamedResponse);

    final rawBody = response.body.trim();
    if (rawBody.isEmpty) {
      throw Exception(
        'Server upload tidak mengembalikan respons (HTTP ${response.statusCode}). '
        'Cek error log PHP/cPanel pada endpoint chat.php?action=upload.',
      );
    }

    Map<String, dynamic> body;
    try {
      body = jsonDecode(rawBody) as Map<String, dynamic>;
    } catch (_) {
      final preview = rawBody.length > 220
          ? '${rawBody.substring(0, 220)}...'
          : rawBody;
      throw Exception(
        'Respons upload bukan JSON valid (HTTP ${response.statusCode}): $preview',
      );
    }

    if (body['success'] == true) {
      return ChatMessage.fromJson(body['data'] as Map<String, dynamic>);
    }
    // Tampilkan pesan debug dari server jika ada
    final serverMsg = body['message'] ?? 'Gagal mengupload file';
    final debugInfo = body['debug'];
    throw Exception(debugInfo != null ? '$serverMsg ($debugInfo)' : serverMsg);
  }

  /// Tandai pesan dibaca via HTTP
  static Future<void> markReadHttp({required int partnerId}) async {
    final token = await AuthService.getToken();
    await http
        .post(
          Uri.parse('$_baseUrl/chat.php?action=mark_read'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'partner_id': partnerId}),
        )
        .timeout(const Duration(seconds: 15));
  }

  /// Hapus pesan (soft delete – set message = 'deleted')
  static Future<void> deleteMessage({required int messageId}) async {
    final token = await AuthService.getToken();
    final response = await http
        .post(
          Uri.parse('$_baseUrl/chat.php?action=delete'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'message_id': messageId}),
        )
        .timeout(const Duration(seconds: 15));
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['success'] != true) {
      throw Exception(body['message'] ?? 'Gagal menghapus pesan');
    }
  }
  static Future<int> getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('user_id') ?? 0;
  }

  /// Ambil token
  static Future<String> getToken() async {
    return await AuthService.getToken();
  }

  /// WebSocket URL
  static String get wsUrl => _wsUrl;
}

/// WebSocket manager untuk real-time chat
class ChatWebSocket {
  WebSocket? _socket;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  bool _isConnected = false;
  bool _isDisposed = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 10;

  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  bool get isConnected => _isConnected;

  /// Connect ke WebSocket
  Future<void> connect() async {
    if (_isDisposed) return;

    try {
      final token = await ChatService.getToken();
      debugPrint('[ChatWS] Connecting to ${ChatService.wsUrl}...');

      _socket = await WebSocket.connect(ChatService.wsUrl);
      _isConnected = true;
      _reconnectAttempts = 0;

      // Auth
      _socket!.add(jsonEncode({'type': 'auth', 'token': token}));

      // Listen
      _socket!.listen(
        (data) {
          try {
            final msg = jsonDecode(data as String) as Map<String, dynamic>;
            _messageController.add(msg);
          } catch (e) {
            debugPrint('[ChatWS] Parse error: $e');
          }
        },
        onDone: () {
          debugPrint('[ChatWS] Connection closed');
          _isConnected = false;
          _scheduleReconnect();
        },
        onError: (e) {
          debugPrint('[ChatWS] Error: $e');
          _isConnected = false;
          _scheduleReconnect();
        },
      );

      // Heartbeat
      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (_isConnected && _socket != null) {
          try {
            _socket!.add(jsonEncode({'type': 'ping'}));
          } catch (_) {}
        }
      });

      debugPrint('[ChatWS] Connected successfully');
    } catch (e) {
      debugPrint('[ChatWS] Connect error: $e');
      _isConnected = false;
      _scheduleReconnect();
    }
  }

  /// Kirim pesan via WebSocket
  void sendMessage({
    required int receiverId,
    required String message,
    String attachmentType = 'none',
    String? attachmentUrl,
    String? attachmentName,
    int? attachmentSize,
    int? replyToMessageId,
  }) {
    if (!_isConnected || _socket == null) {
      debugPrint('[ChatWS] Not connected, cannot send');
      return;
    }
    _socket!.add(
      jsonEncode({
        'type': 'message',
        'receiver_id': receiverId,
        'message': message,
        if (attachmentType != 'none') 'attachment_type': attachmentType,
        if (attachmentUrl != null) 'attachment_url': attachmentUrl,
        if (attachmentName != null) 'attachment_name': attachmentName,
        if (attachmentSize != null) 'attachment_size': attachmentSize,
        if (replyToMessageId != null) 'reply_to_message_id': replyToMessageId,
      }),
    );
  }

  /// Tandai pesan dibaca
  void markRead({required int partnerId}) {
    if (!_isConnected || _socket == null) return;
    _socket!.add(jsonEncode({'type': 'read', 'partner_id': partnerId}));
  }

  /// Kirim typing indicator
  void sendTyping({required int partnerId, required bool isTyping}) {
    if (!_isConnected || _socket == null) return;
    _socket!.add(
      jsonEncode({
        'type': 'typing',
        'partner_id': partnerId,
        'is_typing': isTyping,
      }),
    );
  }

  /// Notify attachment ke penerima (broadcast only, tanpa insert DB)
  void notifyAttachment({
    required int id,
    required int receiverId,
    required String message,
    required String attachmentType,
    String? attachmentUrl,
    String? attachmentName,
    int? attachmentSize,
    String? createdAt,
    int? replyToMessageId,
    String? replyPreview,
    int? replySenderId,
  }) {
    if (!_isConnected || _socket == null) return;
    _socket!.add(
      jsonEncode({
        'type': 'notify',
        'id': id,
        'receiver_id': receiverId,
        'message': message,
        'attachment_type': attachmentType,
        if (attachmentUrl != null) 'attachment_url': attachmentUrl,
        if (attachmentName != null) 'attachment_name': attachmentName,
        if (attachmentSize != null) 'attachment_size': attachmentSize,
        if (createdAt != null) 'created_at': createdAt,
        if (replyToMessageId != null) 'reply_to_message_id': replyToMessageId,
        if (replyPreview != null) 'reply_preview': replyPreview,
        if (replySenderId != null) 'reply_sender_id': replySenderId,
      }),
    );
  }

  /// Broadcast penghapusan pesan ke partner via WS
  void deleteMessageWs({required int messageId, required int receiverId}) {
    if (!_isConnected || _socket == null) return;
    _socket!.add(
      jsonEncode({
        'type': 'delete_message',
        'message_id': messageId,
        'receiver_id': receiverId,
      }),
    );
  }

  void _scheduleReconnect() {
    if (_isDisposed || _reconnectAttempts >= _maxReconnectAttempts) return;
    _reconnectTimer?.cancel();
    final delay = Duration(seconds: 2 * (_reconnectAttempts + 1));
    _reconnectAttempts++;
    debugPrint(
      '[ChatWS] Reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts)',
    );
    _reconnectTimer = Timer(delay, connect);
  }

  /// Dispose resources
  void dispose() {
    _isDisposed = true;
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    _socket?.close();
    _messageController.close();
  }
}
