import 'dart:async';
import 'package:flutter/material.dart';

import 'kiosk_app.dart';
import 'kiosk_config.dart';
import 'kiosk_printer.dart';
import 'kiosk_theme.dart';

/// Final screen. Shows the OR numbers to note down, then returns to idle on its
/// own so the next resident starts clean.
class KioskSuccessScreen extends StatefulWidget {
  final String controlNo;
  final List<String> orNumbers;
  /// Document fee(s) still owed — separate from the purok clearance fee,
  /// which was already settled in cash when the clearance was issued. Zero
  /// when every requested document happens to be free.
  final double totalDue;
  const KioskSuccessScreen({
    super.key,
    required this.controlNo,
    required this.orNumbers,
    this.totalDue = 0,
  });

  @override
  State<KioskSuccessScreen> createState() => _KioskSuccessScreenState();
}

class _KioskSuccessScreenState extends State<KioskSuccessScreen> {
  Timer? _timer;
  // null = still printing / succeeded silently; non-null = shown on-screen.
  // A field kiosk has no adb logcat attached, so this is the only diagnostic
  // there is when the printer doesn't cooperate.
  String? _printError;
  bool _printDone = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(KioskConfig.successTimeout, kioskReturnToIdle);

    // Fire-and-forget as far as the resident-facing flow is concerned — it
    // never blocks navigation or the idle timer above. `kioskFlow` still
    // holds this transaction's details; nothing resets it until
    // kioskReturnToIdle() fires.
    KioskPrinter.instance
        .printReceipt(
      controlNo: widget.controlNo,
      fullName: kioskFlow.fullName,
      purok: kioskFlow.purok,
      selections: List.of(kioskFlow.selections),
      orNumbers: widget.orNumbers,
      totalDue: widget.totalDue,
    )
        .then((error) {
      if (mounted) setState(() { _printError = error; _printDone = true; });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [KioskColors.green, KioskColors.greenDark],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Padding(
                padding: const EdgeInsets.all(36),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle, size: 104, color: KioskColors.gold),
                    const SizedBox(height: 24),
                    const Text(
                      'Request submitted',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.totalDue > 0
                          ? 'Please proceed to the Collector\'s counter to pay\nbefore your documents are processed.'
                          : 'Please wait for your name to be called at the\nreleasing window.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontSize: 18, height: 1.5),
                    ),
                    if (widget.totalDue > 0) ...[
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                        decoration: BoxDecoration(
                          color: KioskColors.gold,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Pay at Collector',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: KioskColors.greenDark)),
                            Text('₱${widget.totalDue.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: KioskColors.greenDark)),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          const Text('Your reference number(s)',
                              style: TextStyle(fontSize: 14, color: Colors.black54)),
                          const SizedBox(height: 8),
                          if (widget.orNumbers.isEmpty)
                            Text('Clearance ${widget.controlNo}',
                                style: const TextStyle(
                                    fontSize: 22, fontWeight: FontWeight.w800))
                          else
                            ...widget.orNumbers.map(
                              (or) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 3),
                                child: Text(or,
                                    style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1)),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (_printDone && _printError != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.print_disabled, color: Colors.white70, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Ticket not printed — please note your reference number(s) '
                                'above.\n$_printError',
                                style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 76,
                      child: ElevatedButton(
                        onPressed: kioskReturnToIdle,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: KioskColors.green,
                        ),
                        child: const Text('Done'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
