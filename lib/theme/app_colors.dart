import 'package:flutter/material.dart';

/// Central palette for the iRequest Dologon app.
///
/// Mirrors the "AeuxGlobal" web theme:
///  - deep [forest] green is the dominant brand colour (app bars, headers,
///    full-bleed screens and primary buttons)
///  - bright [accent] green for highlights, chips, progress and CTAs
///  - pale [mint] for page / card backgrounds
class AppColors {
  AppColors._();

  /// Deep forest — app bars, splash, full-screen green backdrops, primary buttons.
  static const Color forest = Color(0xFF0B3D2E);
  static const Color forestDeep = Color(0xFF082A20);
  static const Color forest700 = Color(0xFF0F4A38);

  /// Alias — the primary brand colour is the forest green.
  static const Color primary = forest;
  static const Color primaryDark = forestDeep;

  /// Bright grass-green accent — chips, highlights, progress, secondary CTAs.
  static const Color accent = Color(0xFF2FA355);
  static const Color accentSoft = Color(0xFF46C56B);

  /// Pale mint — scaffold + card surfaces.
  static const Color mint = Color(0xFFEDF4EC);
  static const Color mintSoft = Color(0xFFF4F8F2);

  /// Near-black green — headings and dark "feature" cards.
  static const Color ink = Color(0xFF0E1A14);

  /// Kept for existing highlight accents (wordmark, badges).
  static const Color gold = Color(0xFFFFD700);
}
