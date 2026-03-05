import 'dart:async';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/maklumat_service.dart';

class WaliMaklumatWidget extends StatefulWidget {
  final int? studentId;
  const WaliMaklumatWidget({super.key, this.studentId});

  @override
  State<WaliMaklumatWidget> createState() => _WaliMaklumatWidgetState();
}

class _WaliMaklumatWidgetState extends State<WaliMaklumatWidget> {
  final PageController _pageController = PageController();
  Timer? _timer;
  int _currentPage = 0;

  List<MaklumatItem> _announcements = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final items = await MaklumatService.getStudentMaklumat(
        studentId: widget.studentId,
      );
      if (!mounted) return;
      setState(() {
        _announcements = items;
        _isLoading = false;
      });
      if (_announcements.isNotEmpty) {
        _startTimer();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      debugPrint('WaliMaklumatWidget: gagal load: $e');
    }
  }

  void _startTimer() {
    _timer?.cancel();
    if (_announcements.length <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_pageController.hasClients) {
        int nextPage = (_currentPage + 1) % _announcements.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox.shrink();
    }

    if (_announcements.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 72,
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppTheme.softShadow,
            border: Border.all(color: AppTheme.grey100, width: 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                final currentItem = _announcements[_currentPage];
                _showDetailBottomSheet(context, currentItem);
              },
              child: PageView.builder(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                itemCount: _announcements.length,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                  _startTimer();
                },
                itemBuilder: (context, index) {
                  final item = _announcements[index];
                  final Color accentColor = item.iconColor;
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        // Icon wrapper
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            item.iconData,
                            color: accentColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        
                        // Text Content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                item.kategori.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: accentColor,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.judul,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Arrow
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppTheme.grey400,
                          size: 20,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Progress indicators (dots) at the bottom
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _announcements.length,
            (index) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              height: 4,
              width: _currentPage == index ? 12 : 4,
              decoration: BoxDecoration(
                color: _currentPage == index
                    ? AppTheme.primaryGreen
                    : AppTheme.grey200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showDetailBottomSheet(BuildContext context, MaklumatItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.only(top: 8),
        decoration: const BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: AppTheme.grey400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category chip only
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: item.iconColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(item.iconData, size: 14, color: item.iconColor),
                            const SizedBox(width: 4),
                            Text(
                              item.kategori.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: item.iconColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Title
                      Text(
                        item.judul,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Tanggal & nama guru di bawah judul
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded,
                              size: 13, color: AppTheme.grey400),
                          const SizedBox(width: 5),
                          Text(
                            item.formattedDate,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          if (item.guruName != null && item.guruName!.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.grey100,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.person_rounded,
                                      size: 12, color: AppTheme.grey400),
                                  const SizedBox(width: 4),
                                  Text(
                                    item.guruName!,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.grey400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Content
                      Text(
                        item.deskripsi,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Optional PDF Attachment
                      if (item.pdfUrl != null && item.pdfUrl!.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.softBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppTheme.softBlue.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.white,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.picture_as_pdf_rounded,
                                  color: Colors.red,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Lampiran Maklumat.pdf',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      'Tap untuk mengunduh',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.download_rounded,
                                color: AppTheme.primaryGreen,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),

              // Action Buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                child: Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                            side: const BorderSide(color: AppTheme.grey200),
                          ),
                        ),
                        child: const Text(
                          'Tutup',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
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
