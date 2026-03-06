import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../theme.dart';
import '../pages/berita_detail_page.dart';
import '../pages/wali_berita_page.dart';

/// Berita sekolah terbaru — tampilan ringkas untuk orang tua.
class WaliGuruInput extends StatefulWidget {
  final Key? refreshKey;

  const WaliGuruInput({super.key, this.refreshKey});

  @override
  State<WaliGuruInput> createState() => _WaliGuruInputState();
}

class _WaliGuruInputState extends State<WaliGuruInput> {
  static const String _apiUrl =
      'https://portal-smalka.com/api/get_berita.php?limit=3';

  List<_SchoolNews> _news = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchNews();
  }

  @override
  void didUpdateWidget(covariant WaliGuruInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-fetch when refreshKey changes (triggered by parent pull-to-refresh)
    if (widget.refreshKey != oldWidget.refreshKey) {
      _fetchNews();
    }
  }

  Future<void> _fetchNews() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await http
          .get(Uri.parse(_apiUrl), headers: {
            'Content-Type': 'application/json',
          })
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (body['success'] != true) {
        throw Exception(body['message'] ?? 'Gagal mengambil berita');
      }

      final List<dynamic> items = body['data'] ?? [];
      final list = items.map((item) {
        return _SchoolNews(
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

  void _openDetail(_SchoolNews item) {
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Berita Sekolah',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Informasi & kegiatan terbaru',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const WaliBeritaPage(),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: AppTheme.primaryGreen,
                ),
                child: const Text(
                  'Lihat Semua',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Skeleton loading state ──
          if (_isLoading)
            ..._buildSkeletonCards()

          // ── Error state ──
          else if (_error != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppTheme.grey100, width: 1),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.cloud_off_rounded,
                    size: 36,
                    color: AppTheme.grey400,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 34,
                    child: TextButton.icon(
                      onPressed: _fetchNews,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text(
                        'Coba Lagi',
                        style: TextStyle(fontSize: 13),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.primaryGreen,
                      ),
                    ),
                  ),
                ],
              ),
            )

          // ── Empty state ──
          else if (_news.isEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppTheme.grey100, width: 1),
              ),
              child: const Text(
                'Belum ada berita terbaru.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
            )

          // ── News list ──
          else
            ..._news.map((item) => _buildNewsCard(context, item)),
        ],
      ),
    );
  }

  // ── Skeleton card loaders ──
  List<Widget> _buildSkeletonCards() {
    return List.generate(2, (_) => _buildSkeletonCard());
  }

  Widget _buildSkeletonCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.grey100, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image skeleton
          const _SkeletonBox(
            width: double.infinity,
            height: 140,
            borderRadius: 0,
          ),
          // Content skeleton
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                // Title line 1
                _SkeletonBox(width: double.infinity, height: 16),
                SizedBox(height: 8),
                // Title line 2
                _SkeletonBox(width: 180, height: 16),
                SizedBox(height: 12),
                // Excerpt line 1
                _SkeletonBox(width: double.infinity, height: 12),
                SizedBox(height: 6),
                // Excerpt line 2
                _SkeletonBox(width: 140, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewsCard(BuildContext context, _SchoolNews item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.grey100, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: item.detailUrl.isNotEmpty
              ? () => _openDetail(item)
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Article Image with loading skeleton
              SizedBox(
                width: double.infinity,
                height: 140,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Base grey
                    Container(color: AppTheme.grey100),

                    // Network image with shimmer while loading
                    if (item.imageUrl.isNotEmpty)
                      Image.network(
                        item.imageUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return const _SkeletonBox(
                            width: double.infinity,
                            height: 140,
                            borderRadius: 0,
                          );
                        },
                        errorBuilder: (_, _e, _s) => const Center(
                          child: Icon(
                            Icons.broken_image_rounded,
                            size: 32,
                            color: AppTheme.grey400,
                          ),
                        ),
                      )
                    else
                      const Center(
                        child: Icon(
                          Icons.article_rounded,
                          size: 40,
                          color: AppTheme.grey400,
                        ),
                      ),

                    // Category Badge
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen,
                          borderRadius: BorderRadius.circular(20),
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

              // Article Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                        height: 1.3,
                      ),
                    ),

                    // Excerpt (if available)
                    if (item.excerpt.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        item.excerpt,
                        maxLines: 2,
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

// ── Shimmer skeleton box ──

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

// ── Data model ──

class _SchoolNews {
  final int id;
  final String title;
  final String imageUrl;
  final String detailUrl;
  final String excerpt;

  const _SchoolNews({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.detailUrl,
    required this.excerpt,
  });
}
