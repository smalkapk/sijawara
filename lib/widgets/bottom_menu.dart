import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';

/// Helper class untuk menangani scroll hide/show pada BottomMenu.
/// Bisa digunakan di halaman mana saja.
class BottomMenuScrollHandler {
  /// Untuk ScrollController (contoh: SingleChildScrollView di HomePage)
  /// Panggil ini dari scroll listener.
  static bool handleScrollController({
    required double currentOffset,
    required double maxOffset,
    required double lastOffset,
    required bool isCurrentlyVisible,
  }) {
    // Ignore bounce/overscroll area
    if (currentOffset < 0 || currentOffset > maxOffset) {
      return isCurrentlyVisible;
    }

    final delta = currentOffset - lastOffset;

    if (delta > 4 && isCurrentlyVisible) {
      return false; // hide
    } else if (delta < -4 && !isCurrentlyVisible) {
      return true; // show
    }

    // Show when at the very top
    if (currentOffset <= 0 && !isCurrentlyVisible) {
      return true;
    }

    return isCurrentlyVisible;
  }

  /// Untuk ScrollNotification (contoh: QuranPage, ProfilePage).
  /// Bungkus widget dengan NotificationListener<ScrollNotification>.
  static bool handleScrollNotification(
    ScrollNotification notification, {
    required bool isCurrentlyVisible,
  }) {
    if (notification is ScrollUpdateNotification) {
      final metrics = notification.metrics;
      final delta = notification.scrollDelta ?? 0;

      // Abaikan saat bounce di top atau bottom (pixels di luar batas normal)
      if (metrics.pixels <= metrics.minScrollExtent ||
          metrics.pixels >= metrics.maxScrollExtent) {
        // Kalau di top, pastikan menu tetap muncul
        if (metrics.pixels <= metrics.minScrollExtent && !isCurrentlyVisible) {
          return true; // show
        }
        return isCurrentlyVisible; // jangan ubah
      }

      if (delta > 2 && isCurrentlyVisible) {
        return false; // hide
      } else if (delta < -2 && !isCurrentlyVisible) {
        return true; // show
      }
    }

    // Show menu saat overscroll di atas
    if (notification is OverscrollNotification) {
      if (notification.overscroll < 0 && !isCurrentlyVisible) {
        return true; // show
      }
    }

    return isCurrentlyVisible;
  }
}

class BottomMenu extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int>? onItemTap;
  final bool isVisible;

  const BottomMenu({
    super.key,
    this.selectedIndex = 1,
    this.onItemTap,
    this.isVisible = true,
  });

  @override
  State<BottomMenu> createState() => _BottomMenuState();
}

class _BottomMenuState extends State<BottomMenu> {
  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return AnimatedSlide(
      offset: widget.isVisible ? Offset.zero : const Offset(0, 1.5),
      duration: const Duration(milliseconds: 350),
      curve: widget.isVisible ? Curves.easeOutCubic : Curves.easeInCubic,
      child: AnimatedOpacity(
        opacity: widget.isVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 250),
        child: Container(
          padding: EdgeInsets.only(top: 12, bottom: 12 + bottomPadding),
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 20,
                offset: const Offset(0, -6),
                spreadRadius: -4,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _MenuButton(
                icon: Icons.menu_book_rounded,
                label: "Al Qur'an",
                isSelected: widget.selectedIndex == 0,
                gradient: AppTheme.cardGradient1,
                onTap: () {
                  HapticFeedback.lightImpact();
                  widget.onItemTap?.call(0);
                },
              ),
              _MenuButton(
                icon: Icons.home_rounded,
                label: 'Beranda',
                isSelected: widget.selectedIndex == 1,
                gradient: AppTheme.mainGradient,
                onTap: () {
                  HapticFeedback.lightImpact();
                  widget.onItemTap?.call(1);
                },
              ),
              _MenuButton(
                icon: Icons.person_rounded,
                label: 'Profil',
                isSelected: widget.selectedIndex == 2,
                gradient: AppTheme.cardGradient2,
                onTap: () {
                  HapticFeedback.lightImpact();
                  widget.onItemTap?.call(2);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final LinearGradient gradient;
  final VoidCallback onTap;

  const _MenuButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.gradient,
    required this.onTap,
  });

  @override
  State<_MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<_MenuButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
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
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: SizedBox(
          width: 70,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  gradient: widget.isSelected ? widget.gradient : null,
                  color: widget.isSelected ? null : AppTheme.bgColor,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: widget.isSelected
                      ? [
                          BoxShadow(
                            color: widget.gradient.colors.first
                                .withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  widget.icon,
                  color: widget.isSelected
                      ? AppTheme.white
                      : AppTheme.grey400,
                  size: 20,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 250),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight:
                      widget.isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: widget.isSelected
                      ? AppTheme.textPrimary
                      : AppTheme.grey400,
                ),
                child: Text(widget.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
