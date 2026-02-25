import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import 'guru_chat_page.dart';

class GuruDiskusiWaliPage extends StatefulWidget {
  const GuruDiskusiWaliPage({super.key});

  @override
  State<GuruDiskusiWaliPage> createState() => _GuruDiskusiWaliPageState();
}

class _GuruDiskusiWaliPageState extends State<GuruDiskusiWaliPage> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  // Dummy data for chat list
  final List<Map<String, dynamic>> _chatData = [
    {
      'wali_name': 'Bapak Budi (Wali Ahmad)',
      'initials': 'BB',
      'last_message': 'Terima kasih informasinya, Pak.',
      'time': '10:30',
      'unread': 0,
      'is_online': false,
      'is_me_last': false,
    },
    {
      'wali_name': 'Ibu Siti (Wali Aisyah)',
      'initials': 'IS',
      'last_message': 'Assalamu\'alaikum, apakah besok ada PR?',
      'time': '09:15',
      'unread': 2,
      'is_online': true,
      'is_me_last': false,
    },
    {
      'wali_name': 'Bapak Joko (Wali Dimas)',
      'initials': 'BJ',
      'last_message': 'Baik Bu, terima kasih atas informasinya.',
      'time': 'Kemarin',
      'unread': 0,
      'is_online': false,
      'is_me_last': true,
    },
    {
      'wali_name': 'Ibu Ani (Wali Farah)',
      'initials': 'IA',
      'last_message': 'Alhamdulillah nilainya bagus. Mohon bimbingannya terus.',
      'time': 'Kemarin',
      'unread': 0,
      'is_online': false,
      'is_me_last': false,
    },
    {
      'wali_name': 'Bapak Rudi (Wali Hana)',
      'initials': 'BR',
      'last_message': 'Anak saya hari ini tidak masuk ya Pak.',
      'time': '22/02/26',
      'unread': 0,
      'is_online': false,
      'is_me_last': false,
    },
  ];

  List<Map<String, dynamic>> get _filteredChats {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) return _chatData;
    return _chatData.where((chat) {
      return (chat['wali_name'] as String).toLowerCase().contains(query) ||
          (chat['last_message'] as String).toLowerCase().contains(query);
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
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
            child: _filteredChats.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: _filteredChats.length,
                    itemBuilder: (context, index) {
                      return _buildChatListItem(_filteredChats[index], index);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          HapticFeedback.lightImpact();
        },
        backgroundColor: AppTheme.primaryGreen,
        elevation: 4,
        child: const Icon(Icons.chat_rounded, color: Colors.white),
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
            setState(() {
              _isSearching = true;
            });
            Future.delayed(const Duration(milliseconds: 100), () {
              _searchFocus.requestFocus();
            });
          },
        ),
        IconButton(
          icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textSecondary),
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
                const Icon(Icons.search_rounded, color: AppTheme.grey400, size: 20),
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
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
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
                    child: const Icon(Icons.close_rounded, color: AppTheme.grey400, size: 18),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline_rounded,
              size: 64, color: AppTheme.grey400.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            'Tidak ada percakapan',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.grey400,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatListItem(Map<String, dynamic> chat, int index) {
    final unreadCount = chat['unread'] as int;
    final isOnline = chat['is_online'] as bool;
    final isMeLast = chat['is_me_last'] as bool;

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GuruChatPage(waliName: chat['wali_name']),
          ),
        );
      },
      child: Container(
        color: AppTheme.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Avatar with online indicator
            Stack(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: _getAvatarColor(index),
                  child: Text(
                    chat['initials'],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (isOnline)
                  Positioned(
                    bottom: 1,
                    right: 1,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFF25D366),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
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
                        child: Text(
                          chat['wali_name'],
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight:
                                unreadCount > 0 ? FontWeight.w800 : FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        chat['time'],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: unreadCount > 0
                              ? const Color(0xFF25D366)
                              : AppTheme.grey400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      // Double check icon for sent messages
                      if (isMeLast) ...[
                        Icon(
                          Icons.done_all_rounded,
                          size: 18,
                          color: const Color(0xFF53BDEB),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          chat['last_message'],
                          style: TextStyle(
                            fontSize: 14,
                            color: unreadCount > 0
                                ? AppTheme.textPrimary
                                : AppTheme.grey400,
                            fontWeight: unreadCount > 0
                                ? FontWeight.w600
                                : FontWeight.w400,
                            height: 1.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (unreadCount > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF25D366),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            unreadCount.toString(),
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
