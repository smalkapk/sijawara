import 'dart:async';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../pages/wali_maklumat_page.dart';

class WaliPengumumanWidget extends StatefulWidget {
  const WaliPengumumanWidget({super.key});

  @override
  State<WaliPengumumanWidget> createState() => _WaliPengumumanWidgetState();
}

class _WaliPengumumanWidgetState extends State<WaliPengumumanWidget> {
  final PageController _pageController = PageController();
  Timer? _timer;
  int _currentPage = 0;

  // Dummy announcements based on the WaliMaklumatPage
  final List<Map<String, dynamic>> _announcements = [
    {
      'title': 'Peringatan Isra Mi\'raj 1447 H di Lingkungan Sekolah',
      'category': 'Acara',
      'color': AppTheme.primaryGreen,
      'icon': Icons.event_rounded,
    },
    {
      'title': 'Jadwal Ujian Tengah Semester Genap 2025/2026',
      'category': 'Akademik',
      'color': AppTheme.softBlue,
      'icon': Icons.school_rounded,
    },
    {
      'title': 'Pengumuman Libur Awal Ramadhan 1447 H',
      'category': 'Info',
      'color': const Color(0xFFEF4444), // Red
      'icon': Icons.info_outline_rounded,
    },
  ];

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_pageController.hasClients) {
        _currentPage = (_currentPage + 1) % _announcements.length;
        _pageController.animateToPage(
          _currentPage,
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
    if (_announcements.isEmpty) return const SizedBox.shrink();

    return Container(
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
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const WaliMaklumatPage()),
            );
          },
          child: Stack(
            children: [
              // Rotating Content
              PageView.builder(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(), // Only auto-scroll
                itemCount: _announcements.length,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemBuilder: (context, index) {
                  final item = _announcements[index];
                  final Color categoryColor = item['color'] as Color;
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        // Icon wrapper
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: categoryColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            item['icon'] as IconData,
                            color: categoryColor,
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
                                item['category'].toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: categoryColor,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item['title'],
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
              
              // Progress indicators (dots) at the bottom
              Positioned(
                bottom: 8,
                left: 0,
                right: 0,
                child: Row(
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
