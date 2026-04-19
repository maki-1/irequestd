import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../services/azure_face_service.dart';
import 'step_progress_bar.dart';
import 'id_verification_screen.dart';

class FaceRecognitionScreen extends StatefulWidget {
  const FaceRecognitionScreen({super.key});

  @override
  State<FaceRecognitionScreen> createState() => _FaceRecognitionScreenState();
}

enum _LivenessStep { position, moveCloser, moveBack, blink, verifying, done, failed }

class _FaceRecognitionScreenState extends State<FaceRecognitionScreen>
    with TickerProviderStateMixin {
  static const Color _lime = Color(0xFF4CFF4C);
  static const Color _gold = Color(0xFFFFD700);

  CameraController? _ctrl;
  bool _cameraReady = false;
  XFile? _photo;
  Uint8List? _photoBytes;

  late AnimationController _pulseCtrl;
  late AnimationController _borderCtrl;

  Timer? _autoScanTimer;
  Timer? _stepTimer;

  _LivenessStep _step = _LivenessStep.position;
  int? _baselineWidth;
  int? _closerWidth;

  static const _closerRatio = 1.20;
  static const _fartherRatio = 0.85;

  // Blink detection
  final _faceDetector = FaceDetector(
    options: FaceDetectorOptions(enableClassification: true),
  );
  bool _blinkProcessing = false;

  String get _hint {
    switch (_step) {
      case _LivenessStep.position:
        return 'Position your face\nin the circle';
      case _LivenessStep.moveCloser:
        return 'Move CLOSER\nto the camera';
      case _LivenessStep.moveBack:
        return 'Now MOVE BACK\nfrom the camera';
      case _LivenessStep.blink:
        return 'Blink your eyes';
      case _LivenessStep.verifying:
        return 'Verifying…';
      case _LivenessStep.done:
        return 'Scan complete!';
      case _LivenessStep.failed:
        return 'Liveness check failed.\nPlease try again.';
    }
  }

  @override
  void initState() {
    super.initState();

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
      _autoScanTimer = Timer(const Duration(milliseconds: 1200), _runStep);
    } catch (_) {}
  }

  Future<void> _runStep() async {
    if (!_cameraReady) return;

    switch (_step) {
      case _LivenessStep.position:
        await _captureBaseline();
        break;
      case _LivenessStep.moveCloser:
        await _captureCloser();
        break;
      case _LivenessStep.moveBack:
        await _captureBack();
        break;
      case _LivenessStep.blink:
        await _detectBlink();
        break;
      default:
        break;
    }
  }

  Future<int?> _captureFaceWidth() async {
    try {
      final photo = await _ctrl!.takePicture();
      final bytes = await photo.readAsBytes();
      final w = await AzureFaceService.detectFaceWidth(bytes);
      return w;
    } catch (_) {
      return null;
    }
  }

  Future<void> _captureBaseline() async {
    setState(() => _step = _LivenessStep.position);
    _borderCtrl.forward();

    // Wait for user to settle face
    await Future.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;

    setState(() => _step = _LivenessStep.verifying);
    final w = await _captureFaceWidth();
    if (!mounted) return;

    if (w == null) {
      _fail('No face detected.\nPosition your face in the circle.');
      return;
    }

    _baselineWidth = w;
    setState(() => _step = _LivenessStep.moveCloser);
    // Give user time to move closer then auto-capture
    _stepTimer = Timer(const Duration(milliseconds: 3000), _captureCloser);
  }

  Future<void> _captureCloser() async {
    _stepTimer?.cancel();
    if (!mounted) return;
    setState(() => _step = _LivenessStep.verifying);

    final w = await _captureFaceWidth();
    if (!mounted) return;

    if (w == null) {
      _fail('No face detected.\nKeep your face in the circle.');
      return;
    }

    final ratio = w / _baselineWidth!;
    if (ratio < _closerRatio) {
      _fail('Please move closer\nto the camera.');
      return;
    }

    _closerWidth = w;
    setState(() => _step = _LivenessStep.moveBack);
    _stepTimer = Timer(const Duration(milliseconds: 3000), _captureBack);
  }

  Future<void> _captureBack() async {
    _stepTimer?.cancel();
    if (!mounted) return;
    setState(() => _step = _LivenessStep.verifying);

    final photo = await _ctrl!.takePicture();
    final bytes = await photo.readAsBytes();

    final w = await AzureFaceService.detectFaceWidth(bytes);
    if (!mounted) return;

    if (w == null) {
      _fail('No face detected.\nKeep your face in the circle.');
      return;
    }

    final ratio = w / _closerWidth!;
    if (ratio > _fartherRatio) {
      _fail('Please move back\nfrom the camera.');
      return;
    }

    // Distance check passed — now blink step
    setState(() => _step = _LivenessStep.blink);
    _detectBlink();
  }

  Future<void> _detectBlink() async {
    if (!mounted) return;
    // Poll for blink over 6 seconds using burst captures
    const maxAttempts = 12;
    const interval = Duration(milliseconds: 500);

    for (int i = 0; i < maxAttempts; i++) {
      if (!mounted || _step != _LivenessStep.blink) return;
      await Future.delayed(interval);
      if (_blinkProcessing) continue;
      _blinkProcessing = true;

      try {
        final photo = await _ctrl!.takePicture();
        final inputImage = InputImage.fromFilePath(photo.path);
        final faces = await _faceDetector.processImage(inputImage);

        if (faces.isNotEmpty) {
          final face = faces.first;
          final left = face.leftEyeOpenProbability ?? 1.0;
          final right = face.rightEyeOpenProbability ?? 1.0;

          if (left < 0.3 && right < 0.3) {
            // Blink detected — capture final selfie
            final finalPhoto = await _ctrl!.takePicture();
            final finalBytes = await finalPhoto.readAsBytes();
            if (!mounted) return;
            setState(() {
              _photo = finalPhoto;
              _photoBytes = finalBytes;
              _step = _LivenessStep.done;
            });
            _borderCtrl.forward();
            return;
          }
        }
      } catch (_) {
        // continue
      } finally {
        _blinkProcessing = false;
      }
    }

    if (mounted && _step == _LivenessStep.blink) {
      _fail('No blink detected.\nPlease blink your eyes.');
    }
  }

  void _fail(String reason) {
    _borderCtrl.reset();
    setState(() {
      _step = _LivenessStep.failed;
      _baselineWidth = null;
      _closerWidth = null;
    });
    // Show failure briefly then restart
    _stepTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      _borderCtrl.reset();
      setState(() => _step = _LivenessStep.position);
      _runStep();
    });
  }

  void _retake() {
    _stepTimer?.cancel();
    _borderCtrl.reset();
    setState(() {
      _photo = null;
      _photoBytes = null;
      _step = _LivenessStep.position;
      _baselineWidth = null;
      _closerWidth = null;
      _blinkProcessing = false;
    });
    Future.delayed(const Duration(milliseconds: 500), _runStep);
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
    _stepTimer?.cancel();
    _pulseCtrl.dispose();
    _borderCtrl.dispose();
    _ctrl?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  bool get _isDone => _step == _LivenessStep.done;
  bool get _isActive =>
      _step == _LivenessStep.position ||
      _step == _LivenessStep.moveCloser ||
      _step == _LivenessStep.moveBack ||
      _step == _LivenessStep.blink;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera always live (no preview of captured photo)
          if (_cameraReady)
            SizedBox.expand(child: CameraPreview(_ctrl!)),

          // Circle overlay
          AnimatedBuilder(
            animation: Listenable.merge([_pulseCtrl, _borderCtrl]),
            builder: (_, __) {
              final Color borderColor;
              if (_isDone) {
                borderColor = _lime;
              } else if (_step == _LivenessStep.failed) {
                borderColor = Colors.redAccent;
              } else {
                borderColor = ColorTween(begin: Colors.white70, end: _lime)
                    .evaluate(_borderCtrl)!;
              }
              final pulse = _isActive ? (1.0 + _pulseCtrl.value * 0.015) : 1.0;
              final Color circleColor;
              switch (_step) {
                case _LivenessStep.position:
                  circleColor = Colors.black.withValues(alpha: 0.62);
                  break;
                case _LivenessStep.moveCloser:
                  circleColor = Colors.blue.withValues(alpha: 0.55);
                  break;
                case _LivenessStep.moveBack:
                  circleColor = Colors.orange.withValues(alpha: 0.55);
                  break;
                case _LivenessStep.blink:
                  circleColor = Colors.purple.withValues(alpha: 0.55);
                  break;
                case _LivenessStep.verifying:
                  circleColor = Colors.black.withValues(alpha: 0.62);
                  break;
                case _LivenessStep.done:
                  circleColor = const Color(0xFF4CFF4C).withValues(alpha: 0.45);
                  break;
                case _LivenessStep.failed:
                  circleColor = Colors.red.withValues(alpha: 0.55);
                  break;
              }
              return CustomPaint(
                size: size,
                painter: _CircleOverlayPainter(
                  pulse: pulse,
                  borderColor: borderColor,
                  circleColor: circleColor,
                  step: _step,
                ),
              );
            },
          ),

          // UI chrome
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
                    key: ValueKey(_step),
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                    decoration: BoxDecoration(
                      color: _step == _LivenessStep.failed
                          ? Colors.red.withValues(alpha: 0.75)
                          : Colors.black54,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      _hint,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
                    ),
                  ),
                ),

                if (_isDone) ...[
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
                        Text('Liveness verified!',
                            style: TextStyle(color: Color(0xFF4CFF4C), fontSize: 14, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 28),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _buildBottomBar(),
                ),

                if (!_isDone) ...[
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
    if (_isDone) {
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

    if (_step == _LivenessStep.verifying) {
      return const SizedBox(
        height: 54,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF4CFF4C))),
              SizedBox(width: 12),
              Text('Verifying…', style: TextStyle(color: Colors.white70, fontSize: 15)),
            ],
          ),
        ),
      );
    }

    return const SizedBox(height: 54);
  }
}

// ── Circle overlay painter ────────────────────────────────────────────────────

class _CircleOverlayPainter extends CustomPainter {
  final double pulse;
  final Color borderColor;
  final Color circleColor;
  final _LivenessStep step;

  const _CircleOverlayPainter({
    required this.pulse,
    required this.borderColor,
    required this.circleColor,
    required this.step,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.43);
    final radius = size.width * 0.38 * pulse;
    final circle = Rect.fromCenter(center: center, width: radius * 2, height: radius * 2);

    // Colored overlay outside circle
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(circle)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, Paint()..color = circleColor);

    // Circle border
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5,
    );

    // Draw direction arrows for closer/back steps
    if (step == _LivenessStep.moveCloser || step == _LivenessStep.moveBack) {
      _drawArrow(canvas, center, radius, step == _LivenessStep.moveCloser);
    }

    // Draw eye icon during blink step
    if (step == _LivenessStep.blink) {
      final eyePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      final eyeY = center.dy + radius + 28;
      // Simple eye shape
      final eyePath = Path()
        ..moveTo(center.dx - 22, eyeY)
        ..quadraticBezierTo(center.dx, eyeY - 14, center.dx + 22, eyeY)
        ..quadraticBezierTo(center.dx, eyeY + 14, center.dx - 22, eyeY);
      canvas.drawPath(eyePath, eyePaint);
      canvas.drawCircle(Offset(center.dx, eyeY), 5,
          Paint()..color = Colors.white.withValues(alpha: 0.85));
    }
  }

  void _drawArrow(Canvas canvas, Offset center, double radius, bool inward) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final arrowY = center.dy + radius + 24;
    const arrowLen = 24.0;

    if (inward) {
      // Two arrows pointing inward (→ center ←)
      // Left arrow →
      canvas.drawLine(Offset(center.dx - 60, arrowY), Offset(center.dx - 18, arrowY), paint);
      canvas.drawLine(Offset(center.dx - 18, arrowY), Offset(center.dx - 30, arrowY - 10), paint);
      canvas.drawLine(Offset(center.dx - 18, arrowY), Offset(center.dx - 30, arrowY + 10), paint);
      // Right arrow ←
      canvas.drawLine(Offset(center.dx + 60, arrowY), Offset(center.dx + 18, arrowY), paint);
      canvas.drawLine(Offset(center.dx + 18, arrowY), Offset(center.dx + 30, arrowY - 10), paint);
      canvas.drawLine(Offset(center.dx + 18, arrowY), Offset(center.dx + 30, arrowY + 10), paint);
    } else {
      // Two arrows pointing outward (← center →)
      canvas.drawLine(Offset(center.dx - 18, arrowY), Offset(center.dx - 18 - arrowLen, arrowY), paint);
      canvas.drawLine(Offset(center.dx - 18 - arrowLen, arrowY), Offset(center.dx - 18 - arrowLen + 12, arrowY - 10), paint);
      canvas.drawLine(Offset(center.dx - 18 - arrowLen, arrowY), Offset(center.dx - 18 - arrowLen + 12, arrowY + 10), paint);
      canvas.drawLine(Offset(center.dx + 18, arrowY), Offset(center.dx + 18 + arrowLen, arrowY), paint);
      canvas.drawLine(Offset(center.dx + 18 + arrowLen, arrowY), Offset(center.dx + 18 + arrowLen - 12, arrowY - 10), paint);
      canvas.drawLine(Offset(center.dx + 18 + arrowLen, arrowY), Offset(center.dx + 18 + arrowLen - 12, arrowY + 10), paint);
    }
  }

  @override
  bool shouldRepaint(_CircleOverlayPainter old) =>
      old.pulse != pulse ||
      old.borderColor != borderColor ||
      old.circleColor != circleColor ||
      old.step != step;
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
