import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../theme.dart';
import '../services/chat_service.dart';
import 'guru_chat_page.dart';

/// Halaman daftar kontak wali murid (untuk Guru Kelas)
/// UI mirip WhatsApp: list chat ke bawah, dengan search
class GuruDiskusiWaliPage extends StatefulWidget {
  const GuruDiskusiWaliPage({super.key});

  @override
  State<GuruDiskusiWaliPage> createState() => _GuruDiskusiWaliPageState();
}

class _GuruDiskusiWaliPageState extends State<GuruDiskusiWaliPage> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  List<WaliContact> _contacts = [];
  bool _isLoading = true;

  // WebSocket untuk update real-time
  ChatWebSocket? _ws;
  StreamSubscription<Map<String, dynamic>>? _wsSub;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await _loadContacts();
      _connectWebSocket();
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint('Gagal init guru diskusi: $e');
    }
  }

  Future<void> _loadContacts() async {
    try {
      setState(() => _isLoading = true);
      final contacts = await ChatService.getContacts();
      if (!mounted) return;
      setState(() {
        _contacts = contacts;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      debugPrint('Gagal load kontak: $e');
    }
  }

  void _connectWebSocket() {
    _ws = ChatWebSocket();
    _wsSub = _ws!.messageStream.listen(_handleWsMessage);
    _ws!.connect();
  }

  void _handleWsMessage(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    if (type == 'new_message') {
      // Refresh daftar kontak untuk update last_message & unread
      _loadContacts();
    }
  }

  List<WaliContact> get _filteredContacts {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) return _contacts;
    return _contacts.where((c) {
      return c.waliName.toLowerCase().contains(query) ||
          c.childrenNames.toLowerCase().contains(query) ||
          (c.lastMessage?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDate = DateTime(dt.year, dt.month, dt.day);

    if (msgDate == today) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    if (msgDate == today.subtract(const Duration(days: 1))) {
      return 'Kemarin';
    }
    return DateFormat('dd/MM/yy').format(dt);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _wsSub?.cancel();
    _ws?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: Column(
        children: [
          _buildAppBar(),
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _filteredContacts.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadContacts,
                        color: AppTheme.primaryGreen,
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding: EdgeInsets.zero,
                          itemCount: _filteredContacts.length,
                          itemBuilder: (context, index) {
                            return _buildChatListItem(
                                _filteredContacts[index], index);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 16, 12),
      child: SafeArea(
        bottom: false,
        child: _isSearching ? _buildSearchBar() : _buildTitleBar(),
      ),
    );
  }

  Widget _buildTitleBar() {
    return Row(
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
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.forum_rounded,
                    size: 14,
                    color: AppTheme.primaryGreen,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Komunikasi',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Diskusi Wali',
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
        IconButton(
          icon: const Icon(Icons.search_rounded, color: AppTheme.textSecondary),
          onPressed: () {
            setState(() => _isSearching = true);
            Future.delayed(const Duration(milliseconds: 100), () {
              _searchFocus.requestFocus();
            });
          },
        ),
        IconButton(
          icon:
              const Icon(Icons.more_vert_rounded, color: AppTheme.textSecondary),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Row(
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _isSearching = false;
              _searchController.clear();
            });
          },
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
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppTheme.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.grey100, width: 1),
            ),
            child: Row(
              children: [
                const Icon(Icons.search_rounded,
                    color: AppTheme.grey400, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocus,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppTheme.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Cari wali murid...',
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color: AppTheme.grey400,
                        fontWeight: FontWeight.w500,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      setState(() {});
                    },
                    child: const Icon(Icons.close_rounded,
                        color: AppTheme.grey400, size: 18),
                  ),
              ],
            ),
          ),
        ),
      ],
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
              strokeWidth: 3,
              color: AppTheme.primaryGreen,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Memuat daftar wali...',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.grey400,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline_rounded,
              size: 64, color: AppTheme.grey400.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            _searchController.text.isNotEmpty
                ? 'Tidak ditemukan'
                : 'Belum ada wali murid',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.grey400,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (_searchController.text.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Wali murid dari kelas Anda\nakan muncul di sini',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.grey400,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChatListItem(WaliContact contact, int index) {
    return InkWell(
      onTap: () async {
        HapticFeedback.lightImpact();
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GuruChatPage(
              waliId: contact.waliId,
              waliName: contact.waliName,
              childrenNames: contact.childrenNames,
            ),
          ),
        );
        // Refresh setelah kembali dari chat
        _loadContacts();
      },
      child: Container(
        color: AppTheme.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 26,
              backgroundColor: _getAvatarColor(index),
              child: Text(
                contact.initials,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Chat info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              contact.waliName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: contact.unreadCount > 0
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (contact.childrenNames.isNotEmpty)
                              Text(
                                'Wali dari ${contact.childrenNames}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.primaryGreen,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTime(contact.lastMessageTime),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: contact.unreadCount > 0
                              ? const Color(0xFF25D366)
                              : AppTheme.grey400,
                        ),
                      ),
                    ],
                  ),
                  if (contact.lastMessage != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (contact.lastMessageIsMe) ...[
                          Icon(
                            Icons.done_all_rounded,
                            size: 18,
                            color: const Color(0xFF53BDEB),
                          ),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            contact.lastMessage!,
                            style: TextStyle(
                              fontSize: 14,
                              color: contact.unreadCount > 0
                                  ? AppTheme.textPrimary
                                  : AppTheme.grey400,
                              fontWeight: contact.unreadCount > 0
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              height: 1.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (contact.unreadCount > 0)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF25D366),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              contact.unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getAvatarColor(int index) {
    final colors = [
      const Color(0xFF1B8A4A),
      const Color(0xFF0D9488),
      const Color(0xFF3B82F6),
      const Color(0xFF8B5CF6),
      const Color(0xFFEA580C),
      const Color(0xFFE11D48),
    ];
    return colors[index % colors.length];
  }
}
