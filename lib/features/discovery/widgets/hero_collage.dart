import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/app_palette.dart';

/// The editorial image collage that sits on the right side of the home hero.
///
/// The composition intentionally mixes one large portrait with smaller scene
/// cards, so it reads as one connected ecosystem instead of a random gallery.
/// Motion is slow and layered: a grounded entrance, gentle floating, a touch of
/// pointer parallax and a crossfading spotlight card.
class HeroCollage extends StatefulWidget {
  const HeroCollage({super.key});

  @override
  State<HeroCollage> createState() => _HeroCollageState();
}

class _HeroCollageState extends State<HeroCollage>
    with TickerProviderStateMixin {
  late final AnimationController _entrance;
  late final AnimationController _float;
  Timer? _sceneTimer;
  int _scene = 0;
  Offset _pointer = Offset.zero;
  bool _reduceMotion = false;
  bool _didStart = false;

  static const _scenes = <_Scene>[
    _Scene(
      asset: 'assets/images/hero/makeup-nigeria.jpg',
      title: 'Beauty',
      caption: 'Makeup artists',
    ),
    _Scene(
      asset: 'assets/images/hero/shop-owner-nigeria.jpg',
      title: 'Local business',
      caption: 'Makers worth finding',
    ),
    _Scene(
      asset: 'assets/images/hero/service.jpg',
      title: 'Home services',
      caption: 'Skilled hands',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _float = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    );
    _entrance.forward();
    _float.repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.of(context).disableAnimations;

    if (!_didStart) {
      _didStart = true;
      _reduceMotion = reduce;
      if (reduce) {
        _entrance.value = 1;
        _float.stop();
      } else {
        _startScenes();
      }
      return;
    }

    if (reduce == _reduceMotion) return;
    _reduceMotion = reduce;
    if (reduce) {
      _sceneTimer?.cancel();
      _sceneTimer = null;
      _float.stop();
      _entrance.value = 1;
    } else {
      if (!_float.isAnimating) _float.repeat(reverse: true);
      _startScenes();
    }
  }

  void _startScenes() {
    _sceneTimer?.cancel();
    _sceneTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted) return;
      setState(() => _scene = (_scene + 1) % _scenes.length);
    });
  }

  @override
  void dispose() {
    _sceneTimer?.cancel();
    _entrance.dispose();
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? palette.amber : palette.amberDeep;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        final width = constraints.maxWidth;
        final height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : (compact ? 380.0 : 560.0);

        return MouseRegion(
          cursor: SystemMouseCursors.basic,
          onHover: _reduceMotion
              ? null
              : (event) {
                  final x = (event.localPosition.dx / width) * 2 - 1;
                  final y = (event.localPosition.dy / height) * 2 - 1;
                  setState(() {
                    _pointer = Offset(
                      x.clamp(-1.0, 1.0).toDouble(),
                      y.clamp(-1.0, 1.0).toDouble(),
                    );
                  });
                },
          onExit: (_) {
            if (!_reduceMotion && _pointer != Offset.zero) {
              setState(() => _pointer = Offset.zero);
            }
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: -height * 0.26,
                right: -width * 0.18,
                child: _Glow(
                  size: width * 0.72,
                  color: accent.withValues(alpha: isDark ? 0.12 : 0.08),
                ),
              ),
              Positioned(
                bottom: -height * 0.32,
                left: -width * 0.20,
                child: _Glow(
                  size: width * 0.66,
                  color: palette.amber.withValues(alpha: 0.10),
                ),
              ),
              if (!compact)
                Positioned(
                  left: width * 0.15,
                  top: height * 0.12,
                  child: _Orbit(size: width * 0.68),
                ),
              if (!compact)
                Positioned(
                  left: width * 0.04,
                  top: height * 0.82,
                  child: _Dot(size: 7, color: accent.withValues(alpha: 0.55)),
                ),
              if (!compact)
                Positioned(
                  right: width * 0.06,
                  top: height * 0.47,
                  child: _Dot(
                    size: 5,
                    color: palette.amber.withValues(alpha: 0.7),
                  ),
                ),

              // Small supporting scenes.
              _slot(
                compact: compact,
                left: compact ? width * 0.02 : width * 0.02,
                top: compact ? height * 0.69 : height * 0.60,
                width: compact ? width * 0.40 : width * 0.34,
                height: compact ? height * 0.27 : height * 0.34,
                phase: 1.7,
                depth: const Offset(6, 4),
                start: 0.24,
                child: const _ArtisanCard(
                  asset: 'assets/images/hero/carpenter-nigeria.jpg',
                  tag: 'Carpentry',
                  alignment: Alignment(0.1, 0),
                ),
              ),
              _slot(
                compact: compact,
                left: compact ? width * 0.46 : width * 0.60,
                top: compact ? height * 0.56 : height * 0.50,
                width: compact ? width * 0.50 : width * 0.36,
                height: compact ? height * 0.34 : height * 0.36,
                phase: 3.1,
                depth: const Offset(8, 5),
                start: 0.30,
                child: const _ArtisanCard(
                  asset: 'assets/images/hero/products.jpg',
                  tag: 'Handmade',
                  alignment: Alignment(0.3, 0),
                ),
              ),
              // The spotlight crossfades between three scenes.
              _slot(
                compact: compact,
                left: compact ? width * 0.62 : width * 0.58,
                top: compact ? height * 0.02 : height * 0.02,
                width: compact ? width * 0.36 : width * 0.36,
                height: compact ? height * 0.34 : height * 0.40,
                phase: 0.4,
                depth: const Offset(5, 3),
                start: 0.15,
                child: _SpotlightCard(
                  scene: _scenes[_scene],
                  reduceMotion: _reduceMotion,
                  pulse: _float,
                ),
              ),

              // Main portrait sits above the supporting scenes.
              _slot(
                compact: compact,
                left: compact ? width * 0.04 : width * 0.08,
                top: compact ? height * 0.11 : height * 0.12,
                width: compact ? width * 0.56 : width * 0.44,
                height: compact ? height * 0.56 : height * 0.60,
                phase: 0,
                depth: const Offset(3, 2),
                start: 0.04,
                child: const _ArtisanCard(
                  asset: 'assets/images/hero_artisan.jpg',
                  tag: 'Tailoring',
                  alignment: Alignment(0.05, -0.12),
                  large: true,
                ),
              ),

              // Floating editorial labels.
              _slot(
                compact: compact,
                left: width * 0.00,
                top: compact ? height * 0.01 : height * 0.00,
                phase: 2.2,
                depth: const Offset(12, 8),
                start: 0.42,
                child: _FloatingLabel(
                  text: 'Skilled hands, quality work.',
                  icon: Icons.auto_awesome_rounded,
                  compact: compact,
                ),
              ),
              _slot(
                compact: compact,
                left: compact ? width * 0.44 : width * 0.55,
                top: compact ? height * 0.89 : height * 0.86,
                phase: 3.8,
                depth: const Offset(14, 9),
                start: 0.48,
                child: _FloatingLabel(
                  text: 'Discover something unique.',
                  icon: Icons.shopping_bag_outlined,
                  compact: compact,
                ),
              ),
              if (!compact)
                _slot(
                  compact: compact,
                  left: width * 0.55,
                  top: height * 0.44,
                  phase: 5.1,
                  depth: const Offset(16, 10),
                  start: 0.54,
                  child: _FloatingLabel(
                    text: 'Your next customer is here.',
                    icon: Icons.forum_outlined,
                    compact: compact,
                  ),
                ),
              if (!compact)
                _slot(
                  compact: compact,
                  left: width * 0.02,
                  top: height * 0.91,
                  phase: 6.2,
                  depth: const Offset(18, 11),
                  start: 0.60,
                  child: _FloatingLabel(
                    text: 'Local talent, endless possibilities.',
                    icon: Icons.public_rounded,
                    compact: compact,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Positioned _slot({
    required bool compact,
    required double left,
    required double top,
    double? width,
    double? height,
    required double phase,
    required Offset depth,
    required double start,
    required Widget child,
  }) {
    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: _floating(child: child, phase: phase, depth: depth, start: start),
    );
  }

  Widget _floating({
    required Widget child,
    required double phase,
    required Offset depth,
    required double start,
  }) {
    final entrance = CurvedAnimation(
      parent: _entrance,
      curve: Interval(start, 1, curve: Curves.easeOutCubic),
    );
    final revealed = FadeTransition(
      opacity: entrance,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(entrance),
        child: child,
      ),
    );

    if (_reduceMotion) return revealed;

    return AnimatedBuilder(
      animation: _float,
      child: revealed,
      builder: (context, child) {
        final t = _float.value * math.pi * 2;
        final dy = math.sin(t + phase) * 4.5;
        final dx = math.cos(t * 0.72 + phase) * 2.2;
        return Transform.translate(
          offset: Offset(
            dx + _pointer.dx * depth.dx,
            dy + _pointer.dy * depth.dy,
          ),
          child: child,
        );
      },
    );
  }
}

class _Scene {
  const _Scene({
    required this.asset,
    required this.title,
    required this.caption,
  });

  final String asset;
  final String title;
  final String caption;
}

class _ArtisanCard extends StatelessWidget {
  const _ArtisanCard({
    required this.asset,
    required this.tag,
    this.alignment = Alignment.center,
    this.large = false,
  });

  final String asset;
  final String tag;
  final Alignment alignment;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final radius = large ? 28.0 : 20.0;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.72),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: palette.shadow,
            blurRadius: large ? 34 : 22,
            offset: Offset(0, large ? 18 : 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              asset,
              fit: BoxFit.cover,
              alignment: alignment,
              filterQuality: FilterQuality.medium,
              semanticLabel: tag,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: large ? 0.62 : 0.54),
                  ],
                  stops: const [0.42, 1],
                ),
              ),
            ),
            Positioned(
              left: large ? 16 : 10,
              right: large ? 16 : 10,
              bottom: large ? 16 : 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: large ? 9 : 7,
                      vertical: large ? 4 : 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.32),
                      ),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: large ? 10 : 8.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpotlightCard extends StatelessWidget {
  const _SpotlightCard({
    required this.scene,
    required this.reduceMotion,
    required this.pulse,
  });

  final _Scene scene;
  final bool reduceMotion;
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.75),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: palette.shadow,
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 900),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (currentChild, previousChildren) => Stack(
                  fit: StackFit.expand,
                  children: [...previousChildren, ?currentChild],
                ),
                child: SizedBox.expand(
                  key: ValueKey(scene.asset),
                  child: Image.asset(
                    scene.asset,
                    fit: BoxFit.cover,
                    alignment: const Alignment(0.1, -0.05),
                    filterQuality: FilterQuality.medium,
                    semanticLabel: scene.title,
                  ),
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.10),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.66),
                  ],
                  stops: const [0, 0.36, 1],
                ),
              ),
            ),
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.30),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.30),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PulseDot(animation: pulse, reduceMotion: reduceMotion),
                    const SizedBox(width: 5),
                    const Text(
                      'SPOTLIGHT',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 11,
              right: 11,
              bottom: 11,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    scene.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    scene.caption,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PulseDot extends StatelessWidget {
  const _PulseDot({required this.animation, required this.reduceMotion});

  final Animation<double> animation;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    if (reduceMotion) {
      return Container(
        width: 5,
        height: 5,
        decoration: const BoxDecoration(
          color: Color(0xFF9BE3B5),
          shape: BoxShape.circle,
        ),
      );
    }

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final pulse = 0.5 + (math.sin(animation.value * math.pi * 2) + 1) / 2;
        return Container(
          width: 7,
          height: 7,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF9BE3B5)
                .withValues(alpha: 0.20 + pulse * 0.15),
          ),
          child: Container(
            width: 4.5,
            height: 4.5,
            decoration: const BoxDecoration(
              color: Color(0xFF9BE3B5),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}

class _FloatingLabel extends StatelessWidget {
  const _FloatingLabel({
    required this.text,
    required this.icon,
    required this.compact,
  });

  final String text;
  final IconData icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? palette.amber : palette.amberDeep;

    return Container(
      constraints: BoxConstraints(maxWidth: compact ? 170 : 220),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 6 : 7,
      ),
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.border.withValues(alpha: 0.85)),
        boxShadow: [
          BoxShadow(
            color: palette.shadow,
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 11 : 12, color: accent),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.inkSoft,
                fontSize: compact ? 9 : 10.5,
                height: 1.2,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Orbit extends StatelessWidget {
  const _Orbit({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: context.palette.border.withValues(alpha: 0.7),
            width: 1,
          ),
        ),
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
