import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/foundation.dart';

import 'kiosk_config.dart';
import 'kiosk_flow.dart';

/// Auto-prints the walk-in's ticket on the kiosk's paired 58mm Bluetooth
/// thermal printer (built and tested against the Xprinter XP-58H) right
/// after a kiosk submission succeeds.
///
/// The XP-58H pairs as classic Bluetooth (SPP), which only a native app can
/// reach — the browser's Web Bluetooth API is BLE-only. So this has no
/// effect at all in the Chrome/web build used for local testing; it only
/// does anything in a native Android build, on a device that already has the
/// printer paired via Android Settings > Bluetooth.
///
/// Deliberately best-effort throughout: a printer that's off, out of paper,
/// or out of range must never block or fail the resident-facing kiosk flow.
/// Every public method swallows its own errors and just logs them.
class KioskPrinter {
  KioskPrinter._();
  static final KioskPrinter instance = KioskPrinter._();

  final BlueThermalPrinter _printer = BlueThermalPrinter.instance;
  bool _connecting = false;

  // This package's printCustom(message, size, align) takes plain ints rather
  // than an enum — these are the conventional values for it (0/1/2 doubling
  // width+height per size step; 0/1/2 for left/center/right).
  static const int _alignLeft = 0;
  static const int _alignCenter = 1;
  static const int _sizeNormal = 0;
  static const int _sizeMedium = 1;
  static const int _sizeLarge = 2;

  /// Returns null on success, or a short reason on failure. Returning the
  /// reason (rather than just logging it) is what lets the success screen
  /// show *why* nothing printed — a kiosk tablet in the field has no adb
  /// logcat attached, so this is the only diagnostic there is.
  Future<String?> _ensureConnected() async {
    try {
      if (await _printer.isConnected == true) return null;
      // Another print already in flight and connecting — don't race it.
      if (_connecting) return 'Already connecting to printer';
      _connecting = true;

      // BLUETOOTH_CONNECT (Android 12+) / the legacy location permission
      // (older Android) are declared by the plugin's own manifest, but are
      // still dangerous permissions Android won't grant just for asking.
      // There's no in-app request here on purpose: a walk-up kiosk has no one
      // to tap an "Allow" dialog, so this is granted once, up front, as part
      // of provisioning the tablet — see PRINTER_SETUP.md. If it was never
      // granted, getBondedDevices()/connect() below just fail like any other
      // unreachable printer, and printing is skipped.
      final bonded = await _printer.getBondedDevices();
      if (bonded.isEmpty) {
        return 'No paired Bluetooth device — pair the printer in '
            'Android Settings and grant its permission (PRINTER_SETUP.md)';
      }

      // A fixed kiosk has exactly one printer paired ahead of time. Match by
      // name when configured (useful once more than one BT device is ever
      // bonded to the tablet); otherwise just take the one bonded device.
      final device = KioskConfig.printerName.isEmpty
          ? bonded.first
          : bonded.firstWhere(
              (d) => (d.name ?? '')
                  .toLowerCase()
                  .contains(KioskConfig.printerName.toLowerCase()),
              orElse: () => bonded.first,
            );

      await _printer.connect(device);
      // connect() can return before the SPP socket is actually writable on
      // some printers — give it a beat before the first write.
      await Future.delayed(const Duration(milliseconds: 400));
      if (await _printer.isConnected != true) {
        return 'Connected to "${device.name}" but the link did not '
            'come up — check it is powered on and in range';
      }
      return null;
    } catch (e) {
      return 'Could not connect to printer: $e';
    } finally {
      _connecting = false;
    }
  }

  /// Prints the walk-in's ticket: control number, name, purok, the
  /// document(s) with their OR numbers, and — the whole reason this prints
  /// immediately rather than waiting — what's still owed at the Collector.
  /// Kept short on purpose for the 50mm-wide, ~30mm-tall stock this kiosk
  /// uses: one line per fact, nothing decorative.
  ///
  /// Returns null on success, or a short human-readable reason it didn't
  /// print — never throws, so the caller can show it without a try/catch.
  Future<String?> printReceipt({
    required String controlNo,
    required String fullName,
    required String purok,
    required List<DocSelection> selections,
    required List<String> orNumbers,
    required double totalDue,
  }) async {
    try {
      final connectError = await _ensureConnected();
      if (connectError != null) {
        debugPrint('[kiosk-printer] $connectError');
        return connectError;
      }

      await _printer.printCustom('BARANGAY DOLOGON', _sizeMedium, _alignCenter);
      await _printer.printCustom('Document Kiosk', _sizeNormal, _alignCenter);
      await _printer.printNewLine();
      await _printer.printCustom('Clearance $controlNo', _sizeNormal, _alignLeft);
      await _printer.printCustom(fullName, _sizeNormal, _alignLeft);
      await _printer.printCustom(purok, _sizeNormal, _alignLeft);
      await _printer.printNewLine();

      for (var i = 0; i < selections.length; i++) {
        final s = selections[i];
        final or = i < orNumbers.length ? orNumbers[i] : '—';
        await _printer.printCustom(s.documentType, _sizeNormal, _alignLeft);
        await _printer.printCustom('OR $or', _sizeNormal, _alignLeft);
      }
      await _printer.printNewLine();

      if (totalDue > 0) {
        await _printer.printCustom('PAY AT COLLECTOR', _sizeMedium, _alignCenter);
        await _printer.printCustom(
          'P${totalDue.toStringAsFixed(2)}',
          _sizeLarge,
          _alignCenter,
        );
      } else {
        await _printer.printCustom('NO BALANCE DUE', _sizeMedium, _alignCenter);
      }

      await _printer.printNewLine();
      await _printer.printCustom(
        DateTime.now().toString().substring(0, 16),
        _sizeNormal,
        _alignCenter,
      );
      // Blank feed so there's enough bare paper to tear by hand — the XP-58H
      // has no auto-cutter, so paperCut() below is expected to be a no-op or
      // throw on it; that's fine, the feed already did the useful part.
      await _printer.printNewLine();
      await _printer.printNewLine();
      try {
        await _printer.paperCut();
      } catch (_) {
        // No cutter on this model — expected.
      }
      return null;
    } catch (e) {
      final reason = 'Print failed: $e';
      debugPrint('[kiosk-printer] $reason');
      return reason;
    }
  }
}
