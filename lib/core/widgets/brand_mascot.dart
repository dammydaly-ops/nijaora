import 'package:flutter/material.dart';

import '../../app/theme/app_palette.dart';

/// The Nijaora fox mascot.
///
/// The same white/green artwork is used in light and dark mode. A soft radial
/// glow adapts to the background so the white fur stays readable on dark green
/// surfaces.
class BrandMascot extends StatelessWidget {
  const BrandMascot({super.key, this.size = 220, this.showGlow = true});

  final double size;
  final bool showGlow;

  static const _asset = 'assets/images/mascot_light.png';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glow = context.palette.amber.withValues(alpha: isDark ? 0.30 : 0.52);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (showGlow)
            Container(
              width: size * 0.82,
              height: size * 0.82,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [glow, glow.withValues(alpha: 0)],
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.all(size * 0.045),
            child: Image.asset(
              _asset,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              gaplessPlayback: true,
            ),
          ),
        ],
      ),
    );
  }
}
