import 'dart:async';
import 'package:flutter/material.dart';

import 'kiosk_app.dart';
import 'kiosk_config.dart';
import 'kiosk_theme.dart';

/// Final screen. Shows the OR numbers to note down, then returns to idle on its
/// own so the next resident starts clean.
class KioskSuccessScreen extends StatefulWidget {
  final String controlNo;
  final List<String> orNumbers;
  const KioskSuccessScreen({
    super.key,
    required this.controlNo,
    required this.orNumbers,
  });

  @override
  State<KioskSuccessScreen> createState() => _KioskSuccessScreenState();
}

class _KioskSuccessScreenState extends State<KioskSuccessScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(KioskConfig.successTimeout, kioskReturnToIdle);
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
                    const Text(
                      'Please wait for your name to be called at the\nreleasing window.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 18, height: 1.5),
                    ),
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
