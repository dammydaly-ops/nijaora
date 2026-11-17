import 'package:flutter/material.dart';

/// Nijaora brand palette.
///
/// The palette is a [ThemeExtension] so every screen can read the same tokens
/// in light and dark mode without hard-coding colours. Dark green is the
/// primary brand colour, light green is the accent, and black/white carry the
/// neutral surfaces and text.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.ink,
    required this.inkSoft,
    required this.cream,
    required this.surface,
    required this.surfaceAlt,
    required this.amber,
    required this.amberDeep,
    required this.amberWash,
    required this.green,
    required this.greenWash,
    required this.red,
    required this.redWash,
    required this.muted,
    required this.border,
    required this.shadow,
  });

  /// Primary text. Near-black in light mode, near-white in dark mode.
  final Color ink;

  /// Secondary text / icons.
  final Color inkSoft;

  /// App background.
  final Color cream;

  /// Card and sheet surface.
  final Color surface;

  /// Muted surface used for chips, tiles and placeholders.
  final Color surfaceAlt;

  /// Light green accent.
  final Color amber;

  /// Dark green brand colour in light mode; light green in dark mode.
  final Color amberDeep;

  /// Soft accent wash.
  final Color amberWash;

  /// Success / verified green.
  final Color green;

  /// Success wash.
  final Color greenWash;

  final Color red;
  final Color redWash;
  final Color muted;
  final Color border;
  final Color shadow;

  static const light = AppPalette(
    ink: Color(0xFF0A0F0C),
    inkSoft: Color(0xFF1C2B22),
    cream: Color(0xFFF5FAF6),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFE9F3EC),
    amber: Color(0xFF9BE3B5),
    amberDeep: Color(0xFF0B5D3B),
    amberWash: Color(0xFFDDF5E6),
    green: Color(0xFF0E7A4A),
    greenWash: Color(0xFFE1F5E9),
    red: Color(0xFFB3261E),
    redWash: Color(0xFFFDECEA),
    muted: Color(0xFF5C6F64),
    border: Color(0xFFD6E5DB),
    shadow: Color(0x14000000),
  );

  static const dark = AppPalette(
    ink: Color(0xFFF2FAF4),
    inkSoft: Color(0xFFC7D8CD),
    cream: Color(0xFF06110B),
    surface: Color(0xFF0D1A12),
    surfaceAlt: Color(0xFF15251B),
    amber: Color(0xFF9BE3B5),
    amberDeep: Color(0xFF6EDD9C),
    amberWash: Color(0xFF153324),
    green: Color(0xFF7FE0A6),
    greenWash: Color(0xFF113322),
    red: Color(0xFFFF8A80),
    redWash: Color(0xFF3A1A18),
    muted: Color(0xFF9BB2A4),
    border: Color(0xFF23382B),
    shadow: Color(0x66000000),
  );

  @override
  AppPalette copyWith({
    Color? ink,
    Color? inkSoft,
    Color? cream,
    Color? surface,
    Color? surfaceAlt,
    Color? amber,
    Color? amberDeep,
    Color? amberWash,
    Color? green,
    Color? greenWash,
    Color? red,
    Color? redWash,
    Color? muted,
    Color? border,
    Color? shadow,
  }) {
    return AppPalette(
      ink: ink ?? this.ink,
      inkSoft: inkSoft ?? this.inkSoft,
      cream: cream ?? this.cream,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      amber: amber ?? this.amber,
      amberDeep: amberDeep ?? this.amberDeep,
      amberWash: amberWash ?? this.amberWash,
      green: green ?? this.green,
      greenWash: greenWash ?? this.greenWash,
      red: red ?? this.red,
      redWash: redWash ?? this.redWash,
      muted: muted ?? this.muted,
      border: border ?? this.border,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  AppPalette lerp(covariant ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      ink: Color.lerp(ink, other.ink, t)!,
      inkSoft: Color.lerp(inkSoft, other.inkSoft, t)!,
      cream: Color.lerp(cream, other.cream, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      amber: Color.lerp(amber, other.amber, t)!,
      amberDeep: Color.lerp(amberDeep, other.amberDeep, t)!,
      amberWash: Color.lerp(amberWash, other.amberWash, t)!,
      green: Color.lerp(green, other.green, t)!,
      greenWash: Color.lerp(greenWash, other.greenWash, t)!,
      red: Color.lerp(red, other.red, t)!,
      redWash: Color.lerp(redWash, other.redWash, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      border: Color.lerp(border, other.border, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

extension AppPaletteContext on BuildContext {
  /// The active light/dark palette.
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;
}
