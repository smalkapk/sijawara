import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme.dart';

/// Halaman detail berita sekolah — membaca artikel in-app.
class BeritaDetailPage extends StatefulWidget {
  final String detailUrl;
  final String title;
  final String imageUrl;

  const BeritaDetailPage({
    super.key,
    required this.detailUrl,
    required this.title,
    this.imageUrl = '',
  });

  @override
  State<BeritaDetailPage> createState() => _BeritaDetailPageState();
}

class _BeritaDetailPageState extends State<BeritaDetailPage> {
  static const String _apiBase =
      'https://portal-smalka.com/api/get_berita_detail.php';
  static const String _summaryApiBase =
      'https://portal-smalka.com/api/alka_rangkum_berita.php';

  bool _isLoading = true;
  String? _error;
  String _content = '';
  String _title = '';
  String _subtitle = '';
  String _date = '';
  String _imageUrl = '';
  List<String> _images = [];

  // AI Summary state
  String _summary = '';
  bool _isSummaryLoading = false;
  bool _summaryError = false;
  bool _isSummaryExpanded = true;

  @override
  void initState() {
    super.initState();
    _title = widget.title;
    _imageUrl = widget.imageUrl;
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final uri = Uri.parse(_apiBase).replace(queryParameters: {
        'url': widget.detailUrl,
      });

      final response = await http.get(uri, headers: {
        'Content-Type': 'application/json',
      }).timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (body['success'] != true) {
        throw Exception(body['message'] ?? 'Gagal memuat artikel');
      }

      final data = body['data'] as Map<String, dynamic>;

      if (mounted) {
        setState(() {
          _title = (data['title'] as String?)?.isNotEmpty == true
              ? data['title']
              : widget.title;
          _imageUrl = (data['image_url'] as String?)?.isNotEmpty == true
              ? data['image_url']
              : widget.imageUrl;
          _subtitle = data['subtitle'] ?? '';
          _date = data['date'] ?? '';
          _content = data['content'] ?? '';
          _images = (data['images'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];
          _isLoading = false;
        });
        // Fetch AI summary setelah artikel berhasil dimuat
        _fetchSummary();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Gagal memuat artikel. Periksa koneksi Anda.';
          _isLoading = false;
        });
      }
    }
  }

  /// Cache key berdasarkan MD5 dari URL artikel
  String get _cacheKey {
    final bytes = utf8.encode(widget.detailUrl);
    final hash = md5.convert(bytes).toString();
    return 'alka_summary_$hash';
  }

  /// Fetch ringkasan AI dengan caching di SharedPreferences
  Future<void> _fetchSummary() async {
    if (_content.isEmpty) return;

    setState(() {
      _isSummaryLoading = true;
      _summaryError = false;
    });

    try {
      // Cek cache dulu
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey);
      if (cached != null && cached.isNotEmpty) {
        if (mounted) {
          setState(() {
            _summary = cached;
            _isSummaryLoading = false;
          });
        }
        return;
      }

      // Tidak ada cache → panggil API
      final response = await http
          .post(
            Uri.parse(_summaryApiBase),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'title': _title,
              'content': _content,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (body['success'] != true) {
        throw Exception(body['error'] ?? 'Gagal merangkum artikel');
      }

      final summary = (body['summary'] as String?) ?? '';

      if (summary.isNotEmpty) {
        // Simpan ke cache
        await prefs.setString(_cacheKey, summary);
      }

      if (mounted) {
        setState(() {
          _summary = summary;
          _isSummaryLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _summaryError = true;
          _isSummaryLoading = false;
        });
      }
    }
  }

  Future<void> _openInBrowser() async {
    final uri = Uri.parse(widget.detailUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: CustomScrollView(
        slivers: [
          // ── App Bar with hero image ──
          SliverAppBar(
            expandedHeight: _imageUrl.isNotEmpty ? 240 : 0,
            pinned: true,
            backgroundColor: AppTheme.deepGreen,
            foregroundColor: Colors.white,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_rounded, size: 20),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                  ),
                  child:
                      const Icon(Icons.public, size: 20),
                ),
                onPressed: _openInBrowser,
                tooltip: 'Buka di browser',
              ),
              const SizedBox(width: 4),
            ],
            flexibleSpace: _imageUrl.isNotEmpty
                ? FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          _imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, e1, s1) => Container(
                            color: AppTheme.deepGreen,
                            child: const Icon(
                              Icons.article_rounded,
                              size: 48,
                              color: Colors.white38,
                            ),
                          ),
                        ),
                        // Gradient overlay
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black54,
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : null,
          ),

          // ── Content ──
          SliverToBoxAdapter(
            child: _isLoading
                ? _buildLoadingSkeleton()
                : _error != null
                    ? _buildError()
                    : _buildArticleContent(),
          ),
        ],
      ),
    );
  }

  // ── Loading skeleton ──
  Widget _buildLoadingSkeleton() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title skeleton
          _SkeletonBox(width: double.infinity, height: 24),
          const SizedBox(height: 8),
          _SkeletonBox(width: 200, height: 24),
          const SizedBox(height: 24),
          // Content skeleton
          for (int i = 0; i < 8; i++) ...[
            _SkeletonBox(
              width: i == 7 ? 180 : double.infinity,
              height: 14,
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 16),
          for (int i = 0; i < 5; i++) ...[
            _SkeletonBox(
              width: i == 4 ? 140 : double.infinity,
              height: 14,
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  // ── Error state ──
  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 48,
            color: AppTheme.grey400,
          ),
          const SizedBox(height: 16),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: _fetchDetail,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Coba Lagi'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primaryGreen,
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: _openInBrowser,
                icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                label: const Text('Buka di Browser'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.grey600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Article content ──
  Widget _buildArticleContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title + badge
        Container(
          color: AppTheme.white,
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
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
              const SizedBox(height: 14),

              // Tanggal
              if (_date.isNotEmpty) ...[  
                Row(
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      size: 14,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _date,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],

              // Title
              Text(
                _title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                  height: 1.35,
                ),
              ),

              // Subtitle
              if (_subtitle.isNotEmpty) ...[  
                const SizedBox(height: 8),
                Text(
                  _subtitle,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                    height: 1.4,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),

        // ── Ringkasan ALKA AI ──
        _buildSummaryBox(),

        const SizedBox(height: 2),

        // Article body
        Container(
          color: AppTheme.white,
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: _buildContentBody(),
        ),

        // Gallery (if images exist)
        if (_images.length > 1) ...[
          const SizedBox(height: 2),
          Container(
            color: AppTheme.white,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Galeri Foto',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 160,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _images.length,
                    separatorBuilder: (_, _2) => const SizedBox(width: 10),
                    itemBuilder: (ctx, idx) {
                      return ClipRRect(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSm),
                        child: Image.network(
                          _images[idx],
                          height: 160,
                          width: 220,
                          fit: BoxFit.cover,
                          errorBuilder: (_, e1, s1) => Container(
                            height: 160,
                            width: 220,
                            color: AppTheme.grey100,
                            child: const Icon(
                              Icons.broken_image_rounded,
                              color: AppTheme.grey400,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 60),
      ],
    );
  }

  // ── Ringkasan ALKA box ──
  Widget _buildSummaryBox() {
    return GestureDetector(
      onTap: (_isSummaryLoading || _summaryError || _summary.isEmpty)
          ? null
          : () => setState(() => _isSummaryExpanded = !_isSummaryExpanded),
      child: Container(
        margin: const EdgeInsets.fromLTRB(0, 2, 0, 0),
        color: AppTheme.white,
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF0FDF4), Color(0xFFECFDF5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: AppTheme.primaryGreen.withValues(alpha: 0.20),
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                decoration: BoxDecoration(
                  border: (_isSummaryExpanded || _isSummaryLoading)
                      ? Border(
                          bottom: BorderSide(
                            color: AppTheme.primaryGreen.withValues(alpha: 0.10),
                          ),
                        )
                      : null,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        size: 16,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Ringkasan ALKA',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.deepGreen,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const Spacer(),
                    // Chevron icon (hanya tampil jika sudah ada summary)
                    if (!_isSummaryLoading && !_summaryError && _summary.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      AnimatedRotation(
                        turns: _isSummaryExpanded ? 0.0 : -0.25,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 20,
                          color: AppTheme.primaryGreen.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Body — expanded or collapsed
              AnimatedCrossFade(
                firstChild: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: _isSummaryLoading
                      ? _buildSummarySkeleton()
                      : _summaryError
                          ? _buildSummaryError()
                          : _summary.isNotEmpty
                              ? _buildSummaryContent()
                              : const SizedBox.shrink(),
                ),
                secondChild: _summary.isNotEmpty
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                        child: Text(
                          _getSummaryPreview(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary.withValues(alpha: 0.7),
                            height: 1.5,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
                crossFadeState: _isSummaryExpanded
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                duration: const Duration(milliseconds: 300),
                sizeCurve: Curves.easeInOut,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Ambil preview teks ringkasan (karakter awal tanpa bullet)
  String _getSummaryPreview() {
    final lines = _summary.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty && !trimmed.startsWith('•') && !trimmed.startsWith('-')) {
        return trimmed;
      }
    }
    return _summary.substring(0, _summary.length.clamp(0, 100));
  }

  Widget _buildSummaryContent() {
    // Parse summary: paragraf pertama + bullet points
    final lines = _summary.split('\n');
    final widgets = <Widget>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.startsWith('•') || trimmed.startsWith('-')) {
        final text = trimmed.replaceFirst(RegExp(r'^[•\-]\s*'), '');
        widgets.add(Padding(
          padding: const EdgeInsets.only(left: 4, top: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 7),
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  color: AppTheme.primaryGreen,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textPrimary,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ));
      } else {
        widgets.add(Padding(
          padding: EdgeInsets.only(top: widgets.isEmpty ? 0 : 8),
          child: Text(
            trimmed,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textPrimary,
              height: 1.6,
            ),
          ),
        ));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _buildSummarySkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Paragraf ringkasan skeleton
        _SkeletonBox(width: double.infinity, height: 12),
        const SizedBox(height: 8),
        _SkeletonBox(width: double.infinity, height: 12),
        const SizedBox(height: 8),
        _SkeletonBox(width: 180, height: 12),
        const SizedBox(height: 16),
        // Bullet points skeleton
        for (int i = 0; i < 3; i++) ...[
          Row(
            children: [
              _SkeletonBox(width: 5, height: 5),
              const SizedBox(width: 10),
              Expanded(child: _SkeletonBox(width: double.infinity, height: 12)),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildSummaryError() {
    return InkWell(
      onTap: _fetchSummary,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              Icons.refresh_rounded,
              size: 16,
              color: AppTheme.textSecondary.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 8),
            Text(
              'Gagal memuat ringkasan. Ketuk untuk coba lagi.',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary.withValues(alpha: 0.6),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentBody() {
    if (_content.isEmpty) {
      return const Text(
        'Konten tidak tersedia.',
        style: TextStyle(
          fontSize: 14,
          color: AppTheme.textSecondary,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    // Parse content berformat markdown-like menjadi widget
    final lines = _content.split('\n');
    final widgets = <Widget>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        widgets.add(const SizedBox(height: 8));
        continue;
      }

      // Heading — skip jika sama dengan judul artikel
      if (trimmed.startsWith('######')) {
        final text = trimmed.replaceFirst(RegExp(r'^#{6}\s*'), '');
        if (text != _title) widgets.add(_heading(text, 6));
      } else if (trimmed.startsWith('#####')) {
        final text = trimmed.replaceFirst(RegExp(r'^#{5}\s*'), '');
        if (text != _title) widgets.add(_heading(text, 5));
      } else if (trimmed.startsWith('####')) {
        final text = trimmed.replaceFirst(RegExp(r'^#{4}\s*'), '');
        if (text != _title) widgets.add(_heading(text, 4));
      } else if (trimmed.startsWith('###')) {
        final text = trimmed.replaceFirst(RegExp(r'^#{3}\s*'), '');
        if (text != _title) widgets.add(_heading(text, 3));
      } else if (trimmed.startsWith('##')) {
        final text = trimmed.replaceFirst(RegExp(r'^#{2}\s*'), '');
        if (text != _title) widgets.add(_heading(text, 2));
      } else if (trimmed.startsWith('#')) {
        final text = trimmed.replaceFirst(RegExp(r'^#\s*'), '');
        if (text != _title) widgets.add(_heading(text, 1));
      }
      // Image markdown — skip jika sama dengan hero image
      else if (trimmed.startsWith('![')) {
        final match =
            RegExp(r'!\[([^\]]*)\]\(([^)]+)\)').firstMatch(trimmed);
        if (match != null) {
          final imgUrl = match.group(2)!;
          // Skip gambar yang sama dengan hero image (bandingkan filename,
          // karena domain bisa beda: og:image vs entry img)
          if (_imageUrl.isNotEmpty && _isSameImage(imgUrl, _imageUrl)) {
            continue;
          }
          widgets.add(Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              child: Image.network(
                match.group(2)!,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, e1, s1) => const SizedBox.shrink(),
              ),
            ),
          ));
        }
      }
      // Bullet point
      else if (trimmed.startsWith('• ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('•  ',
                  style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700)),
              Expanded(
                child: _richText(trimmed.substring(2)),
              ),
            ],
          ),
        ));
      }
      // Normal paragraph
      else {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: _richText(trimmed),
        ));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  /// Bandingkan dua URL gambar berdasarkan nama file (basename).
  /// OG image bisa pakai domain berbeda dari entry img.
  bool _isSameImage(String url1, String url2) {
    if (url1 == url2) return true;
    final name1 = _extractImageName(url1);
    final name2 = _extractImageName(url2);
    return name1.isNotEmpty && name2.isNotEmpty && name1 == name2;
  }

  String _extractImageName(String url) {
    // Cek query param ?i=upload/.../file.jpg
    final uri = Uri.tryParse(url);
    if (uri != null && uri.queryParameters.containsKey('i')) {
      final path = uri.queryParameters['i']!;
      return path.split('/').last;
    }
    // Basename dari path
    return url.split('/').last.split('?').first;
  }

  Widget _heading(String text, int level) {
    final sizes = {1: 22.0, 2: 19.0, 3: 17.0, 4: 15.0, 5: 14.0, 6: 13.0};
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: sizes[level] ?? 15,
          fontWeight: FontWeight.w700,
          color: AppTheme.textPrimary,
          height: 1.35,
        ),
      ),
    );
  }

  Widget _richText(String text) {
    // Parse **bold** dan *italic*
    final spans = <InlineSpan>[];
    final regex = RegExp(r'\*\*(.+?)\*\*|\*(.+?)\*');
    int lastEnd = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      if (match.group(1) != null) {
        spans.add(TextSpan(
          text: match.group(1),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ));
      } else if (match.group(2) != null) {
        spans.add(TextSpan(
          text: match.group(2),
          style: const TextStyle(fontStyle: FontStyle.italic),
        ));
      }
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 14,
          color: AppTheme.textPrimary,
          height: 1.7,
        ),
        children: spans.isEmpty ? [TextSpan(text: text)] : spans,
      ),
    );
  }
}

// ── Skeleton shimmer box ──

class _SkeletonBox extends StatefulWidget {
  final double width;
  final double height;
  const _SkeletonBox({
    required this.width,
    required this.height,
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
            borderRadius: BorderRadius.circular(8),
          ),
        );
      },
    );
  }
}
