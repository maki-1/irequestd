import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'kiosk/kiosk_app.dart';
import 'kiosk/kiosk_flow.dart';
import 'kiosk/kiosk_printer.dart';

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

  // TEMPORARY: printer bring-up diagnostic. Fires one receipt straight at the
  // paired printer on launch, bypassing the backend entirely, when built with
  // --dart-define=KIOSK_TEST_PRINT=true. Remove once the XP-58H is confirmed
  // working end-to-end.
  if (const bool.fromEnvironment('KIOSK_TEST_PRINT')) {
    KioskPrinter.instance
        .printReceipt(
      controlNo: 'PC-TEST1',
      fullName: 'Test Resident',
      purok: 'Purok 1',
      selections: [DocSelection('Barangay Clearance', 'Testing')],
      orNumbers: ['OR-TEST-0001'],
      totalDue: 50.0,
    )
        .then((error) {
      debugPrint('[kiosk-test-print] result: ${error ?? 'OK'}');
    });
  }
}
