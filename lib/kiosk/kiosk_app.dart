import 'dart:async';
import 'package:flutter/material.dart';

import 'kiosk_config.dart';
import 'kiosk_flow.dart';
import 'kiosk_home_screen.dart';
import 'kiosk_theme.dart';

/// One shared navigator so the inactivity timer (and the success screen) can
/// unwind back to the idle screen from anywhere in the flow.
final GlobalKey<NavigatorState> kioskNavigatorKey = GlobalKey<NavigatorState>();

/// One flow object per transaction, reset whenever we return to idle.
final KioskFlow kioskFlow = KioskFlow();

void kioskReturnToIdle() {
  kioskFlow.reset();
  kioskNavigatorKey.currentState?.popUntil((r) => r.isFirst);
}

class KioskApp extends StatelessWidget {
  const KioskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'iRequestDologon Kiosk',
      debugShowCheckedModeBanner: false,
      navigatorKey: kioskNavigatorKey,
      theme: buildKioskTheme(),
      home: const KioskHomeScreen(),
      builder: (context, child) => _InactivityReset(child: child ?? const SizedBox()),
    );
  }
}

/// Resets to the idle screen after [KioskConfig.idleTimeout] of no touches, so
/// a resident who walks away mid-flow does not leave the next person on their
/// half-finished transaction.
class _InactivityReset extends StatefulWidget {
  final Widget child;
  const _InactivityReset({required this.child});

  @override
  State<_InactivityReset> createState() => _InactivityResetState();
}

class _InactivityResetState extends State<_InactivityReset> {
  Timer? _timer;

  void _bump([_]) {
    _timer?.cancel();
    _timer = Timer(KioskConfig.idleTimeout, () {
      // Only act if we have actually navigated away from idle.
      final nav = kioskNavigatorKey.currentState;
      if (nav != null && nav.canPop()) kioskReturnToIdle();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _bump,
      child: widget.child,
    );
  }
}
