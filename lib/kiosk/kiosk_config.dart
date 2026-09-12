/// Compile-time configuration for the walk-in kiosk build.
///
/// Supplied at build time, e.g.
///   flutter run -t lib/main_kiosk.dart -d chrome \
///     --dart-define=KIOSK_API_BASE=http://localhost:5000/api \
///     --dart-define=KIOSK_KEY=dev-kiosk-key
///
/// The kiosk talks to the `irq-admin/server` backend (the one render.yaml
/// deploys), which is a different base URL from the resident app's backend.
class KioskConfig {
  /// Base URL of the kiosk API, including the `/api` suffix, no trailing slash.
  static const String apiBase = String.fromEnvironment(
    'KIOSK_API_BASE',
    defaultValue: 'http://localhost:5000/api',
  );

  /// Shared device key sent as the `X-Kiosk-Key` header. Must match the
  /// backend's `KIOSK_KEY` env var. Empty in local dev where the backend
  /// allows an unset key.
  static const String kioskKey = String.fromEnvironment('KIOSK_KEY');

  /// Return to the idle screen after this long without a touch.
  static const Duration idleTimeout = Duration(seconds: 60);

  /// The success screen returns to idle after this long.
  static const Duration successTimeout = Duration(seconds: 20);

  /// Name (or a distinctive substring, case-insensitive) of the paired
  /// Bluetooth thermal printer to auto-print tickets on — e.g. "XP-58H".
  /// It must already be paired via Android Settings > Bluetooth before the
  /// kiosk runs; KioskPrinter only connects to an already-bonded device, it
  /// never scans for or pairs one itself. Empty uses whichever single device
  /// is bonded, which is fine when the kiosk tablet is paired to exactly one
  /// printer (the normal case).
  static const String printerName = String.fromEnvironment('KIOSK_PRINTER_NAME');
}
