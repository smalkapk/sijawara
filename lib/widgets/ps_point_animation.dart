import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/sound_service.dart';

/// Overlay animation for Public Speaking page point changes (+2 or -2).
///
/// Shows:
/// 1. Point badge appears in center with counting animation
/// 2. Temporary header slides down from top
/// 3. Badge flies to the header
/// 4. Shine sweep on header
/// 5. Header slides back up and disappears
class PSPointAnimationHelper {
  static void show({
    required BuildContext context,
    required int points,
    required VoidCallback onComplete,
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => _PSPointAnimationOverlay(
        points: points,
        onComplete: () {
          entry.remove();
          onComplete();
        },
      ),
    );

    overlay.insert(entry);
  }
}

class _PSPointAnimationOverlay extends StatefulWidget {
  final int points;
  final VoidCallback onComplete;

  const _PSPointAnimationOverlay({
    required this.points,
    required this.onComplete,
  });

  @override
  State<_PSPointAnimationOverlay> createState() =>
      _PSPointAnimationOverlayState();
}

class _PSPointAnimationOverlayState extends State<_PSPointAnimationOverlay>
    with TickerProviderStateMixin {
  // Badge appear
  late AnimationController _appearController;
  late Animation<double> _scaleAnim;
  late Animation<double> _opacityAnim;

  // Badge pulse rings
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  // Count animation
  late AnimationController _countController;
  late Animation<int> _countAnim;

  // Header slide down
  late AnimationController _headerSlideController;
  late Animation<double> _headerSlideAnim;

  // Badge fly to header
  late AnimationController _flyController;
  late Animation<double> _flyProgress;

  // Sparkle at target
  late AnimationController _sparkleController;
  late Animation<double> _sparkleAnim;

  // Shine sweep
  late AnimationController _shineController;
  late Animation<double> _shineAnim;

  // Header slide up (dismiss)
  late AnimationController _headerDismissController;
  late Animation<double> _headerDismissAnim;

  // Background fade out
  late AnimationController _bgFadeController;
  late Animation<double> _bgFadeAnim;

  bool _showBadge = true;
  bool _isFlying = false;
  bool _isSparkle = false;
  bool _isShining = false;
  bool _showHeader = false;

  // Header position (computed once layout known)
  final GlobalKey _headerKey = GlobalKey();
  Offset? _headerCenter;

  bool get _isPositive => widget.points > 0;

  @override
  void initState() {
    super.initState();

    // ── Badge appear ──
    _appearController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.2), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 40),
    ]).animate(CurvedAnimation(
      parent: _appearController,
      curve: Curves.easeOutCubic,
    ));
    _opacityAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _appearController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    // ── Pulse rings ──
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnim = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeOut,
    );

    // ── Count ──
    _countController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _countAnim = IntTween(
      begin: 0,
      end: widget.points.abs(),
    ).animate(CurvedAnimation(
      parent: _countController,
      curve: Curves.easeOutCubic,
    ));

    // ── Header slide down ──
    _headerSlideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _headerSlideAnim = CurvedAnimation(
      parent: _headerSlideController,
      curve: Curves.easeOutCubic,
    );

    // ── Fly ──
    _flyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _flyProgress = CurvedAnimation(
      parent: _flyController,
      curve: Curves.easeInCubic,
    );

    // ── Sparkle ──
    _sparkleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _sparkleAnim = CurvedAnimation(
      parent: _sparkleController,
      curve: Curves.easeOut,
    );

    // ── Shine ──
    _shineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _shineAnim = CurvedAnimation(
      parent: _shineController,
      curve: Curves.easeInOut,
    );

    // ── Header dismiss ──
    _headerDismissController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _headerDismissAnim = CurvedAnimation(
      parent: _headerDismissController,
      curve: Curves.easeInCubic,
    );

    // ── Background fade ──
    _bgFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _bgFadeAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _bgFadeController, curve: Curves.easeOut),
    );

    _startAnimation();
  }

  void _startAnimation() async {
    // Phase 1: Badge appear + count
    _appearController.forward();
    SoundService.playPointAppear();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _countController.forward();
    });
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _pulseController.repeat();
    });
    await _appearController.forward();
    await Future.delayed(const Duration(milliseconds: 500));
    _pulseController.stop();

    // Phase 2: Show header sliding down
    setState(() => _showHeader = true);
    await _headerSlideController.forward();

    // Wait a frame so the header's GlobalKey is placed
    await Future.delayed(const Duration(milliseconds: 50));
    _resolveHeaderCenter();

    // Phase 3: Fly badge to header
    setState(() => _isFlying = true);
    SoundService.playFly();
    await _flyController.forward();

    // Phase 4: Sparkle at header
    setState(() {
      _isSparkle = true;
      _showBadge = false;
    });
    await _sparkleController.forward();

    // Phase 5: Shine sweep on header
    setState(() => _isShining = true);
    await _shineController.forward();
    _shineController.reset();
    await _shineController.forward();

    await Future.delayed(const Duration(milliseconds: 300));

    // Phase 6: Dismiss header upward + fade background
    await Future.wait([
      _headerDismissController.forward(),
      _bgFadeController.forward(),
    ]);

    await Future.delayed(const Duration(milliseconds: 100));
    widget.onComplete();
  }

  void _resolveHeaderCenter() {
    final box =
        _headerKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null) {
      final pos = box.localToGlobal(Offset.zero);
      _headerCenter = Offset(
        pos.dx + box.size.width / 2,
        pos.dy + box.size.height / 2,
      );
    }
  }

  @override
  void dispose() {
    _appearController.dispose();
    _pulseController.dispose();
    _countController.dispose();
    _headerSlideController.dispose();
    _flyController.dispose();
    _sparkleController.dispose();
    _shineController.dispose();
    _headerDismissController.dispose();
    _bgFadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final centerX = screenSize.width / 2;
    final centerY = screenSize.height / 2;
    final topPadding = MediaQuery.of(context).padding.top;

    final badgeColor = _isPositive
        ? const Color(0xFF059669)
        : const Color(0xFFEF4444);
    final badgeGradient = _isPositive
        ? const [Color(0xFF059669), Color(0xFF10B981), Color(0xFF34D399)]
        : const [Color(0xFFB91C1C), Color(0xFFEF4444), Color(0xFFF87171)];
    final ringColor = _isPositive
        ? const Color(0xFF10B981)
        : const Color(0xFFEF4444);

    return Material(
      color: Colors.transparent,
      child: AnimatedBuilder(
        animation: _bgFadeAnim,
        builder: (context, child) {
          return Opacity(
            opacity: _bgFadeAnim.value.clamp(0.0, 1.0),
            child: child,
          );
        },
        child: Stack(
          children: [
            // Semi-transparent background
            AnimatedBuilder(
              animation: _flyController,
              builder: (context, child) {
                return IgnorePointer(
                  child: Container(
                    color: Colors.black
                        .withOpacity(0.3 * (1 - _flyProgress.value)),
                  ),
                );
              },
            ),

            // ── Pulse rings ──
            if (_showBadge && !_isFlying)
              AnimatedBuilder(
                animation: _pulseAnim,
                builder: (context, _) {
                  return Stack(
                    children: List.generate(3, (i) {
                      final delay = i * 0.33;
                      final t = ((_pulseController.value - delay) % 1.0)
                          .clamp(0.0, 1.0);
                      final scale = 1.0 + t * 1.4;
                      final opacity = (1.0 - t) * 0.5;
                      return Positioned(
                        left: centerX - 80,
                        top: centerY - 46,
                        child: Opacity(
                          opacity: opacity,
                          child: Transform.scale(
                            scale: scale,
                            child: Container(
                              width: 160,
                              height: 92,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(
                                  color: ringColor,
                                  width: 2.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),

            // ── Floating point badge ──
            if (_showBadge)
              AnimatedBuilder(
                animation: Listenable.merge([
                  _appearController,
                  _flyController,
                ]),
                builder: (context, child) {
                  double x = centerX;
                  double y = centerY;

                  if (_isFlying && _headerCenter != null) {
                    x = centerX +
                        (_headerCenter!.dx - centerX) * _flyProgress.value;
                    y = centerY +
                        (_headerCenter!.dy - centerY) * _flyProgress.value;
                  }

                  final scale = _isFlying
                      ? 1.0 - (_flyProgress.value * 0.6)
                      : _scaleAnim.value;

                  return Positioned(
                    left: x - 80,
                    top: y - 46,
                    child: Opacity(
                      opacity: _isFlying
                          ? (1 - _flyProgress.value * 0.3)
                          : _opacityAnim.value,
                      child: Transform.scale(
                        scale: scale,
                        child: _buildPointBadge(badgeGradient, badgeColor),
                      ),
                    ),
                  );
                },
              ),

            // Floating mini stars
            if (!_isFlying && _appearController.isCompleted)
              ...List.generate(
                6,
                (i) => _buildFloatingMiniStar(i, centerX, centerY, ringColor),
              ),

            // Sparkle at header
            if (_isSparkle && _headerCenter != null)
              AnimatedBuilder(
                animation: _sparkleAnim,
                builder: (context, _) {
                  return Stack(
                    children: List.generate(10, (i) {
                      return _buildSparkleParticle(i, ringColor);
                    }),
                  );
                },
              ),

            // ── Temporary header ──
            if (_showHeader)
              AnimatedBuilder(
                animation: Listenable.merge([
                  _headerSlideController,
                  _headerDismissController,
                ]),
                builder: (context, child) {
                  // Slide down from top, then slide back up
                  final slideIn = _headerSlideAnim.value;
                  final slideOut = _headerDismissAnim.value;
                  final yOffset = -80.0 * (1 - slideIn) + (-80.0 * slideOut);

                  return Positioned(
                    top: topPadding + 12 + yOffset,
                    left: 24,
                    right: 24,
                    child: Opacity(
                      opacity: ((slideIn) * (1 - slideOut)).clamp(0.0, 1.0),
                      child: child,
                    ),
                  );
                },
                child: _buildTemporaryHeader(),
              ),

            // ── Shine sweep on header ──
            if (_isShining && _showHeader)
              AnimatedBuilder(
                animation: _shineAnim,
                builder: (context, _) {
                  return _buildShineSweep(topPadding);
                },
              ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  // Badge widget
  // ═══════════════════════════════════════

  Widget _buildPointBadge(List<Color> gradient, Color glowColor) {
    final prefix = _isPositive ? '+' : '-';
    final label = _isPositive ? 'PUBLIC SPEAKING' : 'DIHAPUS';
    final desc = _isPositive ? 'Catatan baru tersimpan!' : 'Catatan dihapus';

    return Container(
      width: 160,
      height: 92,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: glowColor.withOpacity(0.5),
            blurRadius: 28,
            spreadRadius: 6,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isPositive
                    ? Icons.record_voice_over_rounded
                    : Icons.remove_circle_outline_rounded,
                color: Colors.white,
                size: 26,
              ),
              const SizedBox(width: 6),
              AnimatedBuilder(
                animation: _countAnim,
                builder: (context, _) {
                  return Text(
                    '$prefix${_countAnim.value}',
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1,
                      decoration: TextDecoration.none,
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.white70,
              letterSpacing: 1.5,
              decoration: TextDecoration.none,
            ),
          ),
          Text(
            desc,
            style: const TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w600,
              color: Colors.white54,
              letterSpacing: 0.5,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════
  // Temporary header (point display)
  // ═══════════════════════════════════════

  Widget _buildTemporaryHeader() {
    final prefix = _isPositive ? '+' : '-';
    final headerGradient = _isPositive
        ? const [Color(0xFF059669), Color(0xFF10B981)]
        : const [Color(0xFFB91C1C), Color(0xFFEF4444)];

    return Container(
      key: _headerKey,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: headerGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: headerGradient[0].withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _isPositive
                  ? Icons.record_voice_over_rounded
                  : Icons.remove_circle_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isPositive ? 'Poin Bertambah!' : 'Poin Berkurang',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _isPositive
                      ? 'Catatan public speaking tersimpan'
                      : 'Catatan public speaking dihapus',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withOpacity(0.8),
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$prefix${widget.points.abs()} Poin',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════
  // Floating stars
  // ═══════════════════════════════════════

  Widget _buildFloatingMiniStar(
      int index, double cx, double cy, Color color) {
    final random = math.Random(index * 42);
    final angle = (index / 6) * 2 * math.pi;
    final radius = 80.0 + random.nextDouble() * 35;
    final delay = index * 0.12;

    return AnimatedBuilder(
      animation: _appearController,
      builder: (context, _) {
        final t = ((_appearController.value - delay) / (1 - delay))
            .clamp(0.0, 1.0);
        final bounce = Curves.elasticOut.transform(t);

        final x = cx + math.cos(angle) * radius * bounce - 8;
        final y = cy + math.sin(angle) * radius * bounce - 8;

        return Positioned(
          left: x,
          top: y,
          child: Opacity(
            opacity: t,
            child: Transform.rotate(
              angle: angle + bounce * math.pi * 0.5,
              child: Icon(
                Icons.star_rounded,
                size: 16 + random.nextDouble() * 8,
                color: color.withOpacity(0.7 + random.nextDouble() * 0.3),
              ),
            ),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════
  // Sparkle particles
  // ═══════════════════════════════════════

  Widget _buildSparkleParticle(int index, Color baseColor) {
    final random = math.Random(index * 77);
    final angle = (index / 10) * 2 * math.pi + random.nextDouble() * 0.5;
    final maxRadius = 30.0 + random.nextDouble() * 40;
    final size = 4.0 + random.nextDouble() * 6;

    final t = _sparkleAnim.value;
    final radius = maxRadius * t;
    final opacity = (1 - t).clamp(0.0, 1.0);

    final x = _headerCenter!.dx + math.cos(angle) * radius - size / 2;
    final y = _headerCenter!.dy + math.sin(angle) * radius - size / 2;

    final colors = [
      baseColor,
      baseColor.withOpacity(0.8),
      Colors.white,
      baseColor.withOpacity(0.6),
    ];

    return Positioned(
      left: x,
      top: y,
      child: Opacity(
        opacity: opacity,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors[index % colors.length],
            boxShadow: [
              BoxShadow(
                color: colors[index % colors.length].withOpacity(0.6),
                blurRadius: 6,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  // Shine sweep on header
  // ═══════════════════════════════════════

  Widget _buildShineSweep(double topPadding) {
    final box =
        _headerKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return const SizedBox.shrink();

    final pos = box.localToGlobal(Offset.zero);
    final w = box.size.width;
    final h = box.size.height;
    final t = _shineAnim.value;

    final sweepX = pos.dx - 30 + (w + 60) * t;

    return Positioned(
      left: pos.dx,
      top: pos.dy,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: w,
          height: h,
          child: Stack(
            children: [
              Positioned(
                left: sweepX - pos.dx - 15,
                top: 0,
                child: Container(
                  width: 30,
                  height: h,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.0),
                        Colors.white.withOpacity(0.5),
                        Colors.white.withOpacity(0.8),
                        Colors.white.withOpacity(0.5),
                        Colors.white.withOpacity(0.0),
                      ],
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
