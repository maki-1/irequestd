import 'package:flutter/material.dart';

import 'kiosk/kiosk_app.dart';

/// Entry point for the walk-in kiosk build.
///
///   flutter run -t lib/main_kiosk.dart -d chrome \
///     --dart-define=KIOSK_API_BASE=http://localhost:5000/api \
///     --dart-define=KIOSK_KEY=dev-kiosk-key
///
/// This is a self-contained flow with no login and no session: it always starts
/// at the idle screen and resets itself after each transaction (and after a
/// period of inactivity). It does not touch the resident app's entry point in
/// lib/main.dart.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KioskApp());
}
