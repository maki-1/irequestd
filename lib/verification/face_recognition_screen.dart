import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'step_progress_bar.dart';
import 'id_verification_screen.dart';

class FaceRecognitionScreen extends StatefulWidget {
  const FaceRecognitionScreen({super.key});

  @override
  State<FaceRecognitionScreen> createState() => _FaceRecognitionScreenState();
}

class _FaceRecognitionScreenState extends State<FaceRecognitionScreen>
    with TickerProviderStateMixin {
  static const Color _lime = Color(0xFF4CFF4C);
  static const Color _gold = Color(0xFFFFD700);

  CameraController? _ctrl;
  bool _cameraReady = false;
  bool _scanning = false;
  bool _captured = false;
  XFile? _photo;
  Uint8List? _photoBytes;

  // Scan line sweeps top→bottom→top continuously while scanning
  late AnimationController _scanLineCtrl;
  // Border pulses gently when idle
  late AnimationController _pulseCtrl;
  // Border color transitions white → lime when scan starts
  late AnimationController _borderCtrl;

  Timer? _autoScanTimer;
  String _hint = 'Position your face\nin the oval';

  @override
  void initState() {
    super.initState();

    _scanLineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed) _scanLineCtrl.reverse();
        if (s == AnimationStatus.dismissed && _scanning) _scanLineCtrl.forward();
      });

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _borderCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _ctrl = CameraController(front, ResolutionPreset.high, enableAudio: false);
      await _ctrl!.initialize();
      if (!mounted) return;
      setState(() => _cameraReady = true);
      // Auto-start scan after camera is ready
      _autoScanTimer = Timer(const Duration(milliseconds: 1200), _startScan);
    } catch (_) {}
  }

  Future<void> _startScan() async {
    if (_scanning || _captured || !_cameraReady) return;
    setState(() {
      _scanning = true;
      _hint = 'Hold still...';
    });
    _borderCtrl.forward();
    _scanLineCtrl.forward();

    // Scan for ~2.5s then capture
    await Future.delayed(const Duration(milliseconds: 2500));
    if (!mounted || _captured) return;

    setState(() => _hint = 'Scanning complete!');
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    try {
      final photo = await _ctrl!.takePicture();
      final bytes = await photo.readAsBytes();
      _scanLineCtrl.stop();
      if (!mounted) return;
      setState(() {
        _photo = photo;
        _photoBytes = bytes;
        _scanning = false;
        _captured = true;
      });
    } catch (_) {
      if (mounted) setState(() => _scanning = false);
    }
  }

  void _retake() {
    _scanLineCtrl.reset();
    _borderCtrl.reset();
    setState(() {
      _photo = null;
      _photoBytes = null;
      _captured = false;
      _scanning = false;
      _hint = 'Position your face\nin the oval';
    });
    Future.delayed(const Duration(milliseconds: 500), _startScan);
  }

  void _continue() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => IdVerificationScreen(facePhotoPath: _photo?.path),
      ),
    );
  }

  @override
  void dispose() {
    _autoScanTimer?.cancel();
    _scanLineCtrl.dispose();
    _pulseCtrl.dispose();
    _borderCtrl.dispose();
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Camera / captured photo ──────────────────────────────────────
          if (_cameraReady && !_captured)
            SizedBox.expand(child: CameraPreview(_ctrl!)),
          if (_captured && _photoBytes != null)
            Image.memory(_photoBytes!, fit: BoxFit.cover, width: size.width, height: size.height),

          // ── Oval overlay ─────────────────────────────────────────────────
          AnimatedBuilder(
            animation: Listenable.merge([_scanLineCtrl, _pulseCtrl, _borderCtrl]),
            builder: (_, __) {
              final borderColor = ColorTween(begin: Colors.white70, end: _lime)
                  .evaluate(_borderCtrl)!;
              final pulse = _captured ? 1.0 : (1.0 + _pulseCtrl.value * 0.015);
              return CustomPaint(
                size: size,
                painter: _OvalOverlayPainter(
                  scanProgress: _scanning ? _scanLineCtrl.value : -1,
                  pulse: pulse,
                  borderColor: _captured ? _lime : borderColor,
                ),
              );
            },
          ),

          // ── UI chrome ────────────────────────────────────────────────────
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Top bar
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                    ),
                    const Spacer(),
                    const Text('Face Scan',
                        style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    const SizedBox(width: 48),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: StepProgressBar(currentStep: 3),
                ),

                const Spacer(),

                // Hint bubble
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    key: ValueKey(_hint),
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      _hint,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
                    ),
                  ),
                ),

                if (_captured) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                    decoration: BoxDecoration(
                      color: _lime.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: _lime.withValues(alpha: 0.5)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded, color: Color(0xFF4CFF4C), size: 18),
                        SizedBox(width: 8),
                        Text('Face captured!',
                            style: TextStyle(color: Color(0xFF4CFF4C), fontSize: 14, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 28),

                // Bottom buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _buildBottomBar(),
                ),

                // Tip chips
                if (!_captured) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    children: const [
                      _TipChip(Icons.wb_sunny_outlined, 'Good lighting'),
                      _TipChip(Icons.face_outlined, 'No glasses'),
                      _TipChip(Icons.remove_red_eye_outlined, 'Eyes open'),
                    ],
                  ),
                ],

                const SizedBox(height: 28),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    if (_captured) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _retake,
              icon: const Icon(Icons.replay_rounded, color: Colors.white70, size: 18),
              label: const Text('Retake', style: TextStyle(color: Colors.white70)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white30),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _continue,
              style: ElevatedButton.styleFrom(
                backgroundColor: _lime,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
              ),
              child: const Text('Continue to ID Scan',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      );
    }

    if (_scanning) {
      return const SizedBox(
        height: 54,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF4CFF4C)),
              ),
              SizedBox(width: 12),
              Text('Scanning your face…',
                  style: TextStyle(color: Colors.white70, fontSize: 15)),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: _cameraReady ? _startScan : null,
        icon: const Icon(Icons.face_rounded),
        label: Text(
          _cameraReady ? 'Start Face Scan' : 'Loading camera…',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _gold,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        ),
      ),
    );
  }
}

// ── Oval overlay painter ───────────────────────────────────────────────────────

class _OvalOverlayPainter extends CustomPainter {
  final double scanProgress; // -1 = no scan line
  final double pulse;
  final Color borderColor;

  const _OvalOverlayPainter({
    required this.scanProgress,
    required this.pulse,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.43);
    final w = size.width * 0.68 * pulse;
    final h = w * 1.35;
    final oval = Rect.fromCenter(center: center, width: w, height: h);

    // Dark overlay with oval cutout
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(oval)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, Paint()..color = Colors.black.withValues(alpha: 0.62));

    // Oval border
    canvas.drawOval(
      oval,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5,
    );

    // Scan line
    if (scanProgress >= 0) {
      final y = oval.top + oval.height * scanProgress;
      canvas.save();
      canvas.clipPath(Path()..addOval(oval));
      canvas.drawLine(
        Offset(oval.left, y),
        Offset(oval.right, y),
        Paint()
          ..shader = LinearGradient(colors: [
            Colors.transparent,
            borderColor.withValues(alpha: 0.9),
            Colors.transparent,
          ]).createShader(oval)
          ..strokeWidth = 2.5,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_OvalOverlayPainter old) =>
      old.scanProgress != scanProgress ||
      old.pulse != pulse ||
      old.borderColor != borderColor;
}

// ── Tip chip ──────────────────────────────────────────────────────────────────

class _TipChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _TipChip(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white60, size: 13),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
        ],
      ),
    );
  }
}
