import 'package:flutter/material.dart';

/// Shared look for the kiosk. Bigger type and tap targets than the phone app:
/// this runs on a wall-mounted touchscreen used by people who are standing,
/// sometimes elderly, and never holding the device.
class KioskColors {
  static const Color green = Color(0xFF0B3D2E);
  static const Color greenDark = Color(0xFF082A20);
  static const Color gold = Color(0xFFFFD700);
  static const Color surface = Color(0xFFEDF4EC);
  static const Color tileBg = Colors.white;
  static const Color danger = Color(0xFFA32B1E);
}

ThemeData buildKioskTheme() {
  final base = ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: KioskColors.green),
    useMaterial3: true,
  );
  return base.copyWith(
    scaffoldBackgroundColor: KioskColors.surface,
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(64, 68),
        backgroundColor: KioskColors.green,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.black12,
        disabledForegroundColor: Colors.black38,
        elevation: 0,
        textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    ),
  );
}

/// "iRequest" (gold, italic) + "Dologon" (context colour). Matches the phone
/// app's wordmark.
Widget kioskWordmark({double size = 34, Color dologon = Colors.white}) {
  return RichText(
    text: TextSpan(
      children: [
        TextSpan(
          text: 'iRequest',
          style: TextStyle(
            fontStyle: FontStyle.italic,
            color: KioskColors.gold,
            fontSize: size,
            fontWeight: FontWeight.bold,
          ),
        ),
        TextSpan(
          text: 'Dologon',
          style: TextStyle(
            color: dologon,
            fontSize: size,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}
