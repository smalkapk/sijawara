import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../theme.dart';
import 'berita_detail_page.dart';

/// Halaman semua berita sekolah — scroll dari terbaru ke terlama.
class WaliBeritaPage extends StatefulWidget {
  const WaliBeritaPage({super.key});

  @override
  State<WaliBeritaPage> createState() => _WaliBeritaPageState();
}

class _WaliBeritaPageState extends State<WaliBeritaPage>
    with SingleTickerProviderStateMixin {
  static const String _apiUrl =
      'https://portal-smalka.com/api/get_berita.php';

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  List<_BeritaItem> _news = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _fadeController.forward();
    _fetchAllNews();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _fetchAllNews() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await http
          .get(Uri.parse(_apiUrl), headers: {
            'Content-Type': 'application/json',
          })
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (body['success'] != true) {
        throw Exception(body['message'] ?? 'Gagal mengambil berita');
      }

      final List<dynamic> items = body['data'] ?? [];
      final list = items.map((item) {
        return _BeritaItem(
          id: item['id'] ?? 0,
          title: item['title'] ?? '',
          imageUrl: item['image_url'] ?? '',
          detailUrl: item['detail_url'] ?? '',
          excerpt: item['excerpt'] ?? '',
        );
      }).toList();

      if (mounted) {
        setState(() {
          _news = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Gagal memuat berita. Periksa koneksi Anda.';
          _isLoading = false;
        });
      }
    }
  }

  void _openDetail(_BeritaItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BeritaDetailPage(
          detailUrl: item.detailUrl,
          title: item.title,
          imageUrl: item.imageUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _isLoading
                    ? _buildLoading()
                    : _error != null
                        ? _buildError()
                        : _news.isEmpty
                            ? _buildEmpty()
                            : RefreshIndicator(
                                onRefresh: _fetchAllNews,
                                color: AppTheme.primaryGreen,
                                backgroundColor: AppTheme.white,
                                child: ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(
                                      24, 8, 24, 40),
                                  physics:
                                      const AlwaysScrollableScrollPhysics(
                                    parent: BouncingScrollPhysics(),
                                  ),
                                  itemCount: _news.length,
                                  itemBuilder: (context, index) {
                                    return TweenAnimationBuilder<double>(
                                      tween:
                                          Tween(begin: 0.0, end: 1.0),
                                      duration: Duration(
                                          milliseconds:
                                              400 + (index * 80)),
                                      curve: Curves.easeOutCubic,
                                      builder: (context, value, child) {
                                        return Opacity(
                                          opacity: value,
                                          child: Transform.translate(
                                            offset: Offset(
                                                0, 20 * (1 - value)),
                                            child: child,
                                          ),
                                        );
                                      },
                                      child: _buildNewsCard(
                                          context, _news[index]),
                                    );
                                  },
                                ),
                              ),
              ),
            ],
          ),
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
                          Icons.newspaper_rounded,
                          size: 14,
                          color: AppTheme.primaryGreen,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Informasi Sekolah',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Berita Sekolah',
                      style:
                          Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Loading ──
  Widget _buildLoading() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 4,
        itemBuilder: (_, __) => _buildSkeletonCard(),
      ),
    );
  }

  Widget _buildSkeletonCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.grey100, width: 1),
        boxShadow: AppTheme.softShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SkeletonBox(width: double.infinity, height: 160, borderRadius: 0),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _SkeletonBox(width: double.infinity, height: 16),
                SizedBox(height: 8),
                _SkeletonBox(width: 180, height: 16),
                SizedBox(height: 12),
                _SkeletonBox(width: double.infinity, height: 12),
                SizedBox(height: 6),
                _SkeletonBox(width: 140, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Error ──
  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 56,
              color: AppTheme.grey400,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _fetchAllNews,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: AppTheme.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Empty ──
  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.article_rounded, size: 48, color: AppTheme.grey400),
          SizedBox(height: 16),
          Text(
            'Belum ada berita.',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ── News card ──
  Widget _buildNewsCard(BuildContext context, _BeritaItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.grey100, width: 1),
        boxShadow: AppTheme.softShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: item.detailUrl.isNotEmpty ? () => _openDetail(item) : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image
              SizedBox(
                width: double.infinity,
                height: 160,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(color: AppTheme.grey100),
                    if (item.imageUrl.isNotEmpty)
                      Image.network(
                        item.imageUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return const _SkeletonBox(
                            width: double.infinity,
                            height: 160,
                            borderRadius: 0,
                          );
                        },
                        errorBuilder: (_, _e, _s) => const Center(
                          child: Icon(Icons.broken_image_rounded,
                              size: 32, color: AppTheme.grey400),
                        ),
                      )
                    else
                      const Center(
                        child: Icon(Icons.article_rounded,
                            size: 40, color: AppTheme.grey400),
                      ),
                    // Badge
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Text(
                          'BERITA',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                        height: 1.3,
                      ),
                    ),
                    if (item.excerpt.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        item.excerpt,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Data model ──

class _BeritaItem {
  final int id;
  final String title;
  final String imageUrl;
  final String detailUrl;
  final String excerpt;

  const _BeritaItem({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.detailUrl,
    required this.excerpt,
  });
}

// ── Skeleton shimmer ──

class _SkeletonBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const _SkeletonBox({
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  State<_SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<_SkeletonBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.04, end: 0.10).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: _animation.value),
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}
