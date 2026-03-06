import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import 'wali_bottom_menu.dart'; // To reuse BottomMenuScrollHandler

class GuruBottomMenu extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int>? onItemTap;
  final bool isVisible;

  const GuruBottomMenu({
    super.key,
    this.selectedIndex = 0,
    this.onItemTap,
    this.isVisible = true,
  });

  @override
  State<GuruBottomMenu> createState() => _GuruBottomMenuState();
}

class _GuruBottomMenuState extends State<GuruBottomMenu> {
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
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 2,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _GuruMenuButton(
                icon: Icons.people_alt,
                label: 'Siswa',
                isSelected: widget.selectedIndex == 0,
                gradient: AppTheme.greenGradient,
                onTap: () {
                  HapticFeedback.lightImpact();
                  widget.onItemTap?.call(0);
                },
              ),
              _GuruMenuButton(
                icon: Icons.home,
                label: 'Beranda',
                isSelected: widget.selectedIndex == 1,
                gradient: AppTheme.mainGradient,
                onTap: () {
                  HapticFeedback.lightImpact();
                  widget.onItemTap?.call(1);
                },
              ),
              _GuruMenuButton(
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

class _GuruMenuButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final LinearGradient gradient;
  final VoidCallback onTap;

  const _GuruMenuButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.gradient,
    required this.onTap,
  });

  @override
  State<_GuruMenuButton> createState() => _GuruMenuButtonState();
}

class _GuruMenuButtonState extends State<_GuruMenuButton>
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
                  boxShadow: widget.isSelected
                      ? [
                          BoxShadow(
                            color: widget.gradient.colors.first.withOpacity(
                              0.3,
                            ),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ]
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
