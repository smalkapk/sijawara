import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../services/connectivity_service.dart';
import 'connectivity_wrapper.dart';

/// Scroll handler for Wali bottom menu - reuses same logic as main app.
class BottomMenuScrollHandler {
  static bool handleScrollController({
    required double currentOffset,
    required double maxOffset,
    required double lastOffset,
    required bool isCurrentlyVisible,
  }) {
    if (currentOffset < 0 || currentOffset > maxOffset) {
      return isCurrentlyVisible;
    }

    final delta = currentOffset - lastOffset;

    if (delta > 4 && isCurrentlyVisible) {
      return false;
    } else if (delta < -4 && !isCurrentlyVisible) {
      return true;
    }

    if (currentOffset <= 0 && !isCurrentlyVisible) {
      return true;
    }

    return isCurrentlyVisible;
  }

  static bool handleScrollNotification(
    ScrollNotification notification, {
    required bool isCurrentlyVisible,
  }) {
    if (notification is ScrollUpdateNotification) {
      final metrics = notification.metrics;
      final delta = notification.scrollDelta ?? 0;

      if (metrics.pixels <= metrics.minScrollExtent ||
          metrics.pixels >= metrics.maxScrollExtent) {
        if (metrics.pixels <= metrics.minScrollExtent && !isCurrentlyVisible) {
          return true;
        }
        return isCurrentlyVisible;
      }

      if (delta > 2 && isCurrentlyVisible) {
        return false;
      } else if (delta < -2 && !isCurrentlyVisible) {
        return true;
      }
    }

    if (notification is OverscrollNotification) {
      if (notification.overscroll < 0 && !isCurrentlyVisible) {
        return true;
      }
    }

    return isCurrentlyVisible;
  }
}

class WaliBottomMenu extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int>? onItemTap;
  final bool isVisible;

  const WaliBottomMenu({
    super.key,
    this.selectedIndex = 0,
    this.onItemTap,
    this.isVisible = true,
  });

  @override
  State<WaliBottomMenu> createState() => _WaliBottomMenuState();
}

class _WaliBottomMenuState extends State<WaliBottomMenu> {
  @override
  void initState() {
    super.initState();
    ConnectivityService.instance.isConnected.addListener(_onConnectivityChanged);
  }

  @override
  void dispose() {
    ConnectivityService.instance.isConnected.removeListener(_onConnectivityChanged);
    super.dispose();
  }

  void _onConnectivityChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final isOffline = !ConnectivityService.instance.isConnected.value;
    final navBarHeight = 62.0 + bottomPadding;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isOffline)
          AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: widget.isVisible ? Curves.easeOutCubic : Curves.easeInCubic,
            transform: widget.isVisible
                ? Matrix4.identity()
                : Matrix4.translationValues(0, navBarHeight - 40, 0),
            child: const OfflineBanner(),
          ),
        AnimatedSlide(
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
            border: Border.all(color: AppTheme.grey100, width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _WaliMenuButton(
                icon: Icons.sensors_rounded,
                label: 'Live',
                isSelected: widget.selectedIndex == 0,
                gradient: AppTheme.greenGradient,
                onTap: () {
                  HapticFeedback.lightImpact();
                  widget.onItemTap?.call(0);
                },
              ),
              _WaliMenuButton(
                icon: Icons.dashboard_rounded,
                label: 'Beranda',
                isSelected: widget.selectedIndex == 1,
                gradient: AppTheme.mainGradient,
                onTap: () {
                  HapticFeedback.lightImpact();
                  widget.onItemTap?.call(1);
                },
              ),
              _WaliMenuButton(
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
      ),
      ],
    );
  }
}

class _WaliMenuButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final LinearGradient gradient;
  final VoidCallback onTap;

  const _WaliMenuButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.gradient,
    required this.onTap,
  });

  @override
  State<_WaliMenuButton> createState() => _WaliMenuButtonState();
}

class _WaliMenuButtonState extends State<_WaliMenuButton>
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
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.9,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
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
                  border: widget.isSelected
                      ? Border.all(color: AppTheme.grey100, width: 1)
                      : null,
                ),
                child: Icon(
                  widget.icon,
                  color: widget.isSelected ? AppTheme.white : AppTheme.grey400,
                  size: 20,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 250),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: widget.isSelected
                      ? FontWeight.w700
                      : FontWeight.w500,
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
