import 'package:flutter/material.dart';
import '../theme.dart';
import '../pages/public_speaking_page.dart';
import '../pages/diskusi_page.dart';

class _MenuItemData {
  final String label;
  final IconData icon;
  final LinearGradient gradient;
  final Color shadowColor;

  const _MenuItemData({
    required this.label,
    required this.icon,
    required this.gradient,
    required this.shadowColor,
  });
}

class MenuButtonsSection extends StatelessWidget {
  const MenuButtonsSection({super.key});

  static final List<_MenuItemData> _items = [
    _MenuItemData(
      label: 'Public Speaking',
      icon: Icons.mic_rounded,
      gradient: const LinearGradient(
        colors: [Color(0xFF065F46), Color(0xFF059669)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      shadowColor: const Color(0xFF065F46).withOpacity(0.3),
    ),
    _MenuItemData(
      label: 'Diskusi Keislaman dan Kebangsaan',
      icon: Icons.menu_book_rounded,
      gradient: const LinearGradient(
        colors: [Color(0xFF0D6E3B), Color(0xFF34D399)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      shadowColor: const Color(0xFF0D6E3B).withOpacity(0.3),
    ),
    _MenuItemData(
      label: 'Setoran',
      icon: Icons.rounded_corner,
      gradient: const LinearGradient(
        colors: [Color(0xFF064E3B), Color(0xFF0D9488)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      shadowColor: const Color(0xFF064E3B).withOpacity(0.3),
    ),
    _MenuItemData(
      label: 'Aduan',
      icon: Icons.campaign_rounded,
      gradient: const LinearGradient(
        colors: [Color(0xFF1B8A4A), Color(0xFF6EE7B7)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      shadowColor: const Color(0xFF1B8A4A).withOpacity(0.3),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Menu Utama',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.45,
            ),
            itemCount: _items.length,
            itemBuilder: (context, index) {
              return _MenuButton(data: _items[index]);
            },
          ),
        ],
      ),
    );
  }
}

class _MenuButton extends StatefulWidget {
  final _MenuItemData data;

  const _MenuButton({required this.data});

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
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) => _controller.forward();
  void _onTapUp(TapUpDetails _) => _controller.reverse();
  void _onTapCancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: () {
        if (widget.data.label == 'Public Speaking') {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const PublicSpeakingPage(),
            ),
          );
        } else if (widget.data.label == 'Diskusi Keislaman dan Kebangsaan') {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const DiskusiPage(),
            ),
          );
        }
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: widget.data.gradient,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            boxShadow: [
              BoxShadow(
                color: widget.data.shadowColor,
                blurRadius: 20,
                offset: const Offset(0, 6),
                spreadRadius: -4,
              ),
            ],
          ),
          child: Stack(
            children: [
              // Decorative circle top-right
              Positioned(
                top: -18,
                right: -18,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.08),
                  ),
                ),
              ),
              // Decorative circle bottom-left
              Positioned(
                bottom: -22,
                left: -12,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.05),
                  ),
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: Icon(
                        widget.data.icon,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        widget.data.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.2,
                          height: 1.2,
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
