import 'package:flutter/material.dart';

import 'kiosk_app.dart';
import 'kiosk_clearance_screen.dart';
import 'kiosk_theme.dart';

/// Idle "attract" screen. One job: get a resident who is holding a purok
/// clearance slip to tap Start.
class KioskHomeScreen extends StatelessWidget {
  const KioskHomeScreen({super.key});

  void _start(BuildContext context) {
    kioskFlow.reset();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const KioskClearanceScreen()),
    );
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
              constraints: const BoxConstraints(maxWidth: 620),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    kioskWordmark(size: 44),
                    const SizedBox(height: 12),
                    const Text(
                      'Barangay Dologon Document Kiosk',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 18),
                    ),
                    const SizedBox(height: 56),
                    const Icon(Icons.badge_outlined, size: 96, color: KioskColors.gold),
                    const SizedBox(height: 32),
                    const Text(
                      'Have your purok clearance slip ready.\n'
                      'You will type its control number to begin.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 20, height: 1.5),
                    ),
                    const SizedBox(height: 48),
                    SizedBox(
                      width: double.infinity,
                      height: 84,
                      child: ElevatedButton.icon(
                        onPressed: () => _start(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: KioskColors.green,
                          textStyle: const TextStyle(
                              fontSize: 26, fontWeight: FontWeight.w800),
                        ),
                        icon: const Icon(Icons.touch_app_rounded, size: 30),
                        label: const Text('Request a Document'),
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
