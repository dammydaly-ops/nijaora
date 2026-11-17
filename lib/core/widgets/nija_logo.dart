import 'package:flutter/material.dart';

import '../../app/theme/app_palette.dart';

class NijaLogo extends StatelessWidget {
  const NijaLogo({
    super.key,
    this.size = 34,
    this.showTagline = false,
    this.onDark = false,
  });

  final double size;
  final bool showTagline;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    // `onDark` means the logo sits on a dark green brand surface in either
    // theme, so use a fixed ivory rather than the theme's `cream` token (which
    // is almost black in dark mode).
    const onDarkInk = Color(0xFFF7FBF8);
    final ink = onDark ? onDarkInk : context.palette.ink;
    final muted = onDark
        ? onDarkInk.withValues(alpha: 0.65)
        : context.palette.muted;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [context.palette.amber, context.palette.amberDeep],
            ),
          ),
          child: Icon(
            Icons.light_mode_rounded,
            size: size * 0.58,
            color: context.palette.ink,
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Nijaora',
              style: TextStyle(
                fontSize: size * 0.58,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
                color: ink,
              ),
            ),
            if (showTagline)
              Text(
                'Find your inner light.',
                style: TextStyle(fontSize: 10.5, color: muted),
              ),
          ],
        ),
      ],
    );
  }
}
