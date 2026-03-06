import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/sound_service.dart';

/// Data for each bonus animation phase
class _BonusPhase {
  final int points;
  final String label;
  final String description;
  final List<Color> gradient;
  final IconData icon;
  final Color iconColor;
  final Color sparkleColor;
  final Color ringColor;

  const _BonusPhase({
    required this.points,
    required this.label,
    required this.description,
    required this.gradient,
    required this.icon,
    required this.iconColor,
    required this.sparkleColor,
    required this.ringColor,
  });
}

/// Overlay entry helper to show the point animation
class PointAnimationHelper {
  static void show({
    required BuildContext context,
    required int earnedPoints,
    required GlobalKey targetKey,
    required VoidCallback onComplete,
    VoidCallback? onShineStart,
    int bonusPoints = 0,
    int wakeUpPoints = 0,
    int deedsPoints = 0,
    int comboBonus = 0,
  }) {
    // Poin shalat saja (tanpa semua bonus)
    final allBonus = bonusPoints + wakeUpPoints + deedsPoints + comboBonus;
    final prayerPoints = (earnedPoints - allBonus).clamp(0, 999);

    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => _PointAnimationOverlay(
        earnedPoints: prayerPoints,
        bonusPoints: bonusPoints,
        wakeUpPoints: wakeUpPoints,
        deedsPoints: deedsPoints,
        comboBonus: comboBonus,
        targetKey: targetKey,
        onComplete: () {
          entry.remove();
          onComplete();
        },
        onShineStart: onShineStart,
      ),
    );

    overlay.insert(entry);
  }
}

class _PointAnimationOverlay extends StatefulWidget {
  final int earnedPoints;
  final int bonusPoints;
  final int wakeUpPoints;
  final int deedsPoints;
  final int comboBonus;
  final GlobalKey targetKey;
  final VoidCallback onComplete;
  final VoidCallback? onShineStart;

  const _PointAnimationOverlay({
    required this.earnedPoints,
    this.bonusPoints = 0,
    this.wakeUpPoints = 0,
    this.deedsPoints = 0,
    this.comboBonus = 0,
    required this.targetKey,
    required this.onComplete,
    this.onShineStart,
  });

  @override
  State<_PointAnimationOverlay> createState() => _PointAnimationOverlayState();
}

class _PointAnimationOverlayState extends State<_PointAnimationOverlay>
    with TickerProviderStateMixin {
  // ── Primary phase (prayer points) ──
  late AnimationController _appearController;
  late Animation<double> _scaleAnim;
  late Animation<double> _opacityAnim;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;
  late AnimationController _countController;
  late Animation<int> _countAnim;
  late AnimationController _flyController;
  late Animation<double> _flyProgress;
  late AnimationController _sparkleController;
  late Animation<double> _sparkleAnim;
  late AnimationController _shineController;
  late Animation<double> _shineAnim;

  // ── Generic bonus phase (reusable across all bonus types) ──
  late AnimationController _bonusAppearController;
  late Animation<double> _bonusScaleAnim;
  late Animation<double> _bonusOpacityAnim;
  late AnimationController _bonusCountController;
  Animation<int>? _bonusCountAnim;
  late AnimationController _bonusFlyController;
  late Animation<double> _bonusFlyProgress;
  late AnimationController _bonusSparkleController;
  late Animation<double> _bonusSparkleAnim;
  late AnimationController _bonusPulseController;
  late Animation<double> _bonusPulseAnim;

  Offset? _targetOffset;
  Size? _targetSize;
  bool _isFlying = false;
  bool _isSparkle = false;
  bool _isShining = false;
  bool _showBadge = true;

  // Current bonus state
  bool _showBonus = false;
  bool _isBonusFlying = false;
  bool _isBonusSparkle = false;
  _BonusPhase? _currentBonusPhase;

  // Bonus phases queue
  late List<_BonusPhase> _bonusPhases;

  @override
  void initState() {
    super.initState();

    // Build bonus phases list dynamically
    _bonusPhases = [];
    if (widget.bonusPoints > 0) {
      _bonusPhases.add(_BonusPhase(
        points: widget.bonusPoints,
        label: 'BONUS 5/5',
        description: 'Semua shalat tercatat!',
        gradient: const [Color(0xFFB91C1C), Color(0xFFEF4444), Color(0xFFF87171)],
        icon: Icons.stars_rounded,
        iconColor: Colors.white,
        sparkleColor: const Color(0xFFEF4444),
        ringColor: const Color(0xFFEF4444),
      ));
    }
    if (widget.wakeUpPoints > 0) {
      _bonusPhases.add(_BonusPhase(
        points: widget.wakeUpPoints,
        label: 'BANGUN PAGI',
        description: 'Bangun sebelum subuh',
        gradient: const [Color(0xFF059669), Color(0xFF10B981), Color(0xFF34D399)],
        icon: Icons.stars_rounded,
        iconColor: Colors.white,
        sparkleColor: const Color(0xFF10B981),
        ringColor: const Color(0xFF10B981),
      ));
    }
    if (widget.deedsPoints > 0) {
      _bonusPhases.add(_BonusPhase(
        points: widget.deedsPoints,
        label: 'KEBAIKAN',
        description: 'Amal baik hari ini',
        gradient: const [Color(0xFF059669), Color(0xFF10B981), Color(0xFF34D399)],
        icon: Icons.stars_rounded,
        iconColor: Colors.white,
        sparkleColor: const Color(0xFF10B981),
        ringColor: const Color(0xFF10B981),
      ));
    }
    if (widget.comboBonus > 0) {
      _bonusPhases.add(_BonusPhase(
        points: widget.comboBonus,
        label: 'COMBO BONUS',
        description: 'Bangun pagi + kebaikan!',
        gradient: const [Color(0xFFB91C1C), Color(0xFFEF4444), Color(0xFFF87171)],
        icon: Icons.stars_rounded,
        iconColor: Colors.white,
        sparkleColor: const Color(0xFFEF4444),
        ringColor: const Color(0xFFEF4444),
      ));
    }

    // ── Primary animations ──
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

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnim = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeOut,
    );

    _countController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _countAnim = IntTween(begin: 0, end: widget.earnedPoints).animate(
      CurvedAnimation(
        parent: _countController,
        curve: Curves.easeOutCubic,
      ),
    );

    _flyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _flyProgress = CurvedAnimation(
      parent: _flyController,
      curve: Curves.easeInCubic,
    );

    _sparkleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _sparkleAnim = CurvedAnimation(
      parent: _sparkleController,
      curve: Curves.easeOut,
    );

    _shineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _shineAnim = CurvedAnimation(
      parent: _shineController,
      curve: Curves.easeInOut,
    );

    // ── Bonus animations (reusable across all bonus phases) ──
    _bonusAppearController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _bonusScaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.4), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 0.9), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.1), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 1.1, end: 1.0), weight: 10),
    ]).animate(CurvedAnimation(
      parent: _bonusAppearController,
      curve: Curves.easeOutCubic,
    ));
    _bonusOpacityAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _bonusAppearController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      ),
    );

    _bonusCountController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _bonusFlyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _bonusFlyProgress = CurvedAnimation(
      parent: _bonusFlyController,
      curve: Curves.easeInCubic,
    );

    _bonusSparkleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _bonusSparkleAnim = CurvedAnimation(
      parent: _bonusSparkleController,
      curve: Curves.easeOut,
    );

    _bonusPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _bonusPulseAnim = CurvedAnimation(
      parent: _bonusPulseController,
      curve: Curves.easeOut,
    );

    _startAnimation();
  }

  void _startAnimation() async {
    _resolveTargetOffset();

    // ── Phase 1: Primary badge (prayer points) — skip if 0 ──
    if (widget.earnedPoints > 0) {
      _appearController.forward();
      SoundService.playPointAppear(); // 🔊 ding!
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _countController.forward();
      });
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _pulseController.repeat();
      });
      await _appearController.forward();
      await Future.delayed(const Duration(milliseconds: 600));
      _pulseController.stop();

      _resolveTargetOffset();

      // Fly to header
      setState(() => _isFlying = true);
      SoundService.playFly(); // 🔊 whoosh!
      await _flyController.forward();

      // Sparkle at target
      setState(() {
        _isSparkle = true;
        _showBadge = false;
      });
      await _sparkleController.forward();
    } else {
      // No prayer points — hide primary badge immediately
      setState(() => _showBadge = false);
    }

    // ── Iterate through all bonus phases ──
    for (final phase in _bonusPhases) {
      await _animateBonusPhase(phase);
    }

    // ── Final shine sweep ──
    setState(() => _isShining = true);
    widget.onShineStart?.call();
    await _shineController.forward();
    _shineController.reset();
    await _shineController.forward();

    await Future.delayed(const Duration(milliseconds: 200));
    widget.onComplete();
  }

  /// Animate a single bonus phase: appear → count → pulse → fly → sparkle
  Future<void> _animateBonusPhase(_BonusPhase phase) async {
    // Reset all bonus controllers for reuse
    _bonusAppearController.reset();
    _bonusCountController.reset();
    _bonusFlyController.reset();
    _bonusSparkleController.reset();
    _bonusPulseController.reset();

    // Create fresh count animation with correct target value
    _bonusCountAnim = IntTween(begin: 0, end: phase.points).animate(
      CurvedAnimation(
        parent: _bonusCountController,
        curve: Curves.easeOutCubic,
      ),
    );

    // Show the bonus badge
    setState(() {
      _currentBonusPhase = phase;
      _showBonus = true;
      _isBonusFlying = false;
      _isBonusSparkle = false;
    });

    // Appear animation
    _bonusAppearController.forward();
    SoundService.playBonusAppear(); // 🔊 achievement!
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _bonusCountController.forward();
    });
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _bonusPulseController.repeat();
    });
    await _bonusAppearController.forward();
    await Future.delayed(const Duration(milliseconds: 700));
    _bonusPulseController.stop();

    // Fly to target
    setState(() => _isBonusFlying = true);
    SoundService.playFly(); // 🔊 whoosh!
    await _bonusFlyController.forward();

    // Sparkle at target
    setState(() {
      _isBonusSparkle = true;
      _showBonus = false;
    });
    await _bonusSparkleController.forward();

    // Brief pause between phases
    await Future.delayed(const Duration(milliseconds: 150));
  }

  void _resolveTargetOffset() {
    final box =
        widget.targetKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null) {
      final pos = box.localToGlobal(Offset.zero);
      _targetOffset = Offset(
        pos.dx + box.size.width / 2,
        pos.dy + box.size.height / 2,
      );
      _targetSize = box.size;
    }
  }

  @override
  void dispose() {
    _appearController.dispose();
    _pulseController.dispose();
    _countController.dispose();
    _flyController.dispose();
    _sparkleController.dispose();
    _shineController.dispose();
    _bonusAppearController.dispose();
    _bonusCountController.dispose();
    _bonusFlyController.dispose();
    _bonusSparkleController.dispose();
    _bonusPulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final centerX = screenSize.width / 2;
    final centerY = screenSize.height / 2;

    return Material(
      color: Colors.transparent,
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

          // ── Primary badge pulse rings ──
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
                                color: const Color(0xFF10B981),
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

          // ── Primary floating point badge ──
          if (_showBadge)
            AnimatedBuilder(
              animation: Listenable.merge([
                _appearController,
                _flyController,
              ]),
              builder: (context, child) {
                double x = centerX;
                double y = centerY;

                if (_isFlying && _targetOffset != null) {
                  x = centerX +
                      (_targetOffset!.dx - centerX) * _flyProgress.value;
                  y = centerY +
                      (_targetOffset!.dy - centerY) * _flyProgress.value;
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
                      child: _buildPointBadge(),
                    ),
                  ),
                );
              },
            ),

          // Primary floating mini stars
          if (!_isFlying && _appearController.isCompleted)
            ...List.generate(
                6, (i) => _buildFloatingMiniStar(i, centerX, centerY)),

          // Primary sparkle at target
          if (_isSparkle && _targetOffset != null)
            AnimatedBuilder(
              animation: _sparkleAnim,
              builder: (context, _) {
                return Stack(
                  children: List.generate(10, (i) {
                    return _buildSparkleParticle(
                        i, _sparkleAnim, const Color(0xFF10B981));
                  }),
                );
              },
            ),

          // ── Bonus badge pulse rings ──
          if (_showBonus && !_isBonusFlying && _currentBonusPhase != null)
            AnimatedBuilder(
              animation: _bonusPulseAnim,
              builder: (context, _) {
                return Stack(
                  children: List.generate(3, (i) {
                    final delay = i * 0.33;
                    final t = ((_bonusPulseController.value - delay) % 1.0)
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
                                color: _currentBonusPhase!.ringColor,
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

          // ── Bonus floating badge ──
          if (_showBonus && _currentBonusPhase != null)
            AnimatedBuilder(
              animation: Listenable.merge([
                _bonusAppearController,
                _bonusFlyController,
              ]),
              builder: (context, child) {
                double x = centerX;
                double y = centerY;

                if (_isBonusFlying && _targetOffset != null) {
                  x = centerX +
                      (_targetOffset!.dx - centerX) *
                          _bonusFlyProgress.value;
                  y = centerY +
                      (_targetOffset!.dy - centerY) *
                          _bonusFlyProgress.value;
                }

                final scale = _isBonusFlying
                    ? 1.0 - (_bonusFlyProgress.value * 0.6)
                    : _bonusScaleAnim.value;

                return Positioned(
                  left: x - 80,
                  top: y - 46,
                  child: Opacity(
                    opacity: _isBonusFlying
                        ? (1 - _bonusFlyProgress.value * 0.3)
                        : _bonusOpacityAnim.value,
                    child: Transform.scale(
                      scale: scale,
                      child: _buildBonusBadge(_currentBonusPhase!),
                    ),
                  ),
                );
              },
            ),

          // Bonus floating stars
          if (_showBonus &&
              !_isBonusFlying &&
              _bonusAppearController.isCompleted &&
              _currentBonusPhase != null)
            ...List.generate(
                8, (i) => _buildBonusFloatingStar(i, centerX, centerY)),

          // Bonus sparkle at target
          if (_isBonusSparkle &&
              _targetOffset != null &&
              _currentBonusPhase != null)
            AnimatedBuilder(
              animation: _bonusSparkleAnim,
              builder: (context, _) {
                return Stack(
                  children: List.generate(12, (i) {
                    return _buildSparkleParticle(
                        i, _bonusSparkleAnim, _currentBonusPhase!.sparkleColor);
                  }),
                );
              },
            ),

          // ── Shine sweep on header badge ──
          if (_isShining && _targetOffset != null && _targetSize != null)
            AnimatedBuilder(
              animation: _shineAnim,
              builder: (context, _) {
                return _buildShineSweep();
              },
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════
  // Badge builders
  // ═══════════════════════════════════════

  Widget _buildPointBadge() {
    return Container(
      width: 160,
      height: 92,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF059669), Color(0xFF10B981), Color(0xFF34D399)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.stars_rounded,
                color: Colors.white,
                size: 26,
              ),
              const SizedBox(width: 6),
              AnimatedBuilder(
                animation: _countAnim,
                builder: (context, _) {
                  return Text(
                    '+${_countAnim.value}',
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
          const Text(
            'SHALAT',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.white70,
              letterSpacing: 1.5,
              decoration: TextDecoration.none,
            ),
          ),
          const Text(
            'Poin shalat harian',
            style: TextStyle(
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

  Widget _buildBonusBadge(_BonusPhase phase) {
    return Container(
      width: 160,
      height: 92,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: phase.gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    phase.icon,
                    color: phase.iconColor,
                    size: 26,
                  ),
                  const SizedBox(width: 6),
                  _bonusCountAnim != null
                      ? AnimatedBuilder(
                          animation: _bonusCountAnim!,
                          builder: (context, _) {
                            return Text(
                              '+${_bonusCountAnim!.value}',
                              style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                height: 1,
                                decoration: TextDecoration.none,
                              ),
                            );
                          },
                        )
                      : Text(
                          '+${phase.points}',
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1,
                            decoration: TextDecoration.none,
                          ),
                        ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            phase.label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.white70,
              letterSpacing: 1.5,
              decoration: TextDecoration.none,
            ),
          ),
          Text(
            phase.description,
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
  // Star & sparkle builders
  // ═══════════════════════════════════════

  Widget _buildFloatingMiniStar(int index, double cx, double cy) {
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
                color: const Color(0xFF34D399)
                    .withOpacity(0.7 + random.nextDouble() * 0.3),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBonusFloatingStar(int index, double cx, double cy) {
    final phase = _currentBonusPhase;
    if (phase == null) return const SizedBox.shrink();

    final random = math.Random(index * 55);
    final angle = (index / 8) * 2 * math.pi;
    final radius = 80.0 + random.nextDouble() * 35;
    final delay = index * 0.1;

    return AnimatedBuilder(
      animation: _bonusAppearController,
      builder: (context, _) {
        final t = ((_bonusAppearController.value - delay) / (1 - delay))
            .clamp(0.0, 1.0);
        final bounce = Curves.elasticOut.transform(t);

        final x = cx + math.cos(angle) * radius * bounce - 10;
        final y = cy + math.sin(angle) * radius * bounce - 10;

        final icons = [
          Icons.star_rounded,
          Icons.auto_awesome_rounded,
          Icons.star_rounded,
          Icons.auto_awesome_rounded,
        ];

        return Positioned(
          left: x,
          top: y,
          child: Opacity(
            opacity: t,
            child: Transform.rotate(
              angle: angle + bounce * math.pi * 0.5,
              child: Icon(
                icons[index % icons.length],
                size: 16 + random.nextDouble() * 10,
                color: Color.lerp(
                  phase.sparkleColor,
                  phase.iconColor,
                  random.nextDouble(),
                )!
                    .withOpacity(0.8),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSparkleParticle(
      int index, Animation<double> anim, Color baseColor) {
    final random = math.Random(index * 77);
    final angle = (index / 10) * 2 * math.pi + random.nextDouble() * 0.5;
    final maxRadius = 30.0 + random.nextDouble() * 40;
    final size = 4.0 + random.nextDouble() * 6;

    final t = anim.value;
    final radius = maxRadius * t;
    final opacity = (1 - t).clamp(0.0, 1.0);

    final x = _targetOffset!.dx + math.cos(angle) * radius - size / 2;
    final y = _targetOffset!.dy + math.sin(angle) * radius - size / 2;

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

  Widget _buildShineSweep() {
    final box =
        widget.targetKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return const SizedBox.shrink();

    final pos = box.localToGlobal(Offset.zero);
    final w = _targetSize!.width;
    final h = _targetSize!.height;
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
