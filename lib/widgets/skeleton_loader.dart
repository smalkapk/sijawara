import 'package:flutter/material.dart';
import '../theme.dart';

/// Skeleton loader untuk shimmer effect
class SkeletonLoader extends StatefulWidget {
  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  const SkeletonLoader({
    super.key,
    this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
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
            borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: [
                0.0,
                _animation.value.clamp(0.0, 1.0),
                (_animation.value + 0.3).clamp(0.0, 1.0),
              ],
              colors: [
                AppTheme.grey100,
                AppTheme.grey100.withOpacity(0.5),
                AppTheme.grey100,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Skeleton untuk horizontal calendar
class HorizontalCalendarSkeleton extends StatelessWidget {
  const HorizontalCalendarSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 7,
        itemBuilder: (context, index) {
          return Container(
            width: 68,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              children: [
                const SkeletonLoader(height: 12, width: 30),
                const SizedBox(height: 8),
                SkeletonLoader(
                  height: 62,
                  borderRadius: BorderRadius.circular(16),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Skeleton untuk prayer countdown card
class PrayerCountdownSkeleton extends StatelessWidget {
  const PrayerCountdownSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SkeletonLoader(height: 14, width: 120),
                    const SizedBox(height: 8),
                    const SkeletonLoader(height: 24, width: 80),
                  ],
                ),
                SkeletonLoader(
                  height: 48,
                  width: 48,
                  borderRadius: BorderRadius.circular(16),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const SkeletonLoader(height: 12, width: 180),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SkeletonLoader(
                    height: 80,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SkeletonLoader(
                    height: 80,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SkeletonLoader(
              height: 48,
              borderRadius: BorderRadius.circular(16),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton untuk Public Speaking note cards
class PublicSpeakingSkeleton extends StatelessWidget {
  const PublicSpeakingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      itemCount: 3,
      itemBuilder: (context, index) => _buildCardSkeleton(),
    );
  }

  Widget _buildCardSkeleton() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0F0F0), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: icon + title + date chip
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonLoader(
                height: 36,
                width: 36,
                borderRadius: BorderRadius.circular(10),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SkeletonLoader(height: 14, width: double.infinity),
                    const SizedBox(height: 6),
                    SkeletonLoader(
                      height: 12,
                      width: 100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SkeletonLoader(
                    height: 12,
                    width: 60,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  const SizedBox(height: 10),
                  SkeletonLoader(
                    height: 24,
                    width: 24,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Materi row
          const SkeletonLoader(height: 11, width: 50),
          const SizedBox(height: 6),
          const SkeletonLoader(height: 14, width: double.infinity),
          // Divider
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: SkeletonLoader(height: 1, width: double.infinity),
          ),
          // Mentor row
          const SkeletonLoader(height: 11, width: 50),
          const SizedBox(height: 6),
          SkeletonLoader(
            height: 14,
            width: 160,
            borderRadius: BorderRadius.circular(6),
          ),
        ],
      ),
    );
  }
}

/// Skeleton untuk menu buttons section
class MenuButtonsSkeleton extends StatelessWidget {
  const MenuButtonsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SkeletonLoader(
                  height: 100,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SkeletonLoader(
                  height: 100,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SkeletonLoader(
                  height: 100,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SkeletonLoader(
                  height: 100,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
