import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../services/api_service.dart';
import 'step_progress_bar.dart';
import 'verification_waiting_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public entry point
// ─────────────────────────────────────────────────────────────────────────────

class IdVerificationScreen extends StatefulWidget {
  final String? facePhotoPath;
  const IdVerificationScreen({super.key, this.facePhotoPath});

  @override
  State<IdVerificationScreen> createState() => _IdVerificationScreenState();
}

class _IdVerificationScreenState extends State<IdVerificationScreen> {
  static const Color _green = Color(0xFF1A6B1A);
  static const Color _lime = Color(0xFF4CFF4C);

  String? _idType;
  String? _idName;
  XFile? _idFront;
  XFile? _idBack;
  Uint8List? _idFrontBytes;
  Uint8List? _idBackBytes;
  bool _isLoading = false;

  static const _primaryIds = [
    'Passport',
    'National ID (PhilID)',
    'UMID (Unified Multi-Purpose ID)',
    "Driver's License",
    'PRC License',
    'Senior Citizen ID',
    'PWD ID',
  ];

  static const _secondaryIds = [
    "Voter's ID",
    'Postal ID',
    'School ID',
    'Company / Employment ID',
    'Barangay ID',
    'Birth Certificate (Short Form)',
    'Marriage Certificate',
  ];

  List<String> get _idOptions =>
      _idType == 'primary' ? _primaryIds : _secondaryIds;

  bool get _canSubmit =>
      _idType != null && _idName != null && _idFront != null && _idBack != null;

  // Open the live camera scanner and wait for a captured photo
  Future<void> _scanId({required bool isFront}) async {
    final result = await Navigator.push<XFile?>(
      context,
      MaterialPageRoute(
        builder: (_) => _IdCameraPage(
          label: isFront ? 'Front of ID' : 'Back of ID',
        ),
        fullscreenDialog: true,
      ),
    );
    if (result == null) return;
    final bytes = await result.readAsBytes();
    setState(() {
      if (isFront) {
        _idFront = result;
        _idFrontBytes = bytes;
      } else {
        _idBack = result;
        _idBackBytes = bytes;
      }
    });
  }

  Future<void> _handleSubmit() async {
    if (!_canSubmit) return;
    setState(() => _isLoading = true);
    try {
      final result = await ApiService.submitStep3(
        idType: _idType!,
        idName: _idName!,
        facePhotoPath: widget.facePhotoPath,
        idFrontPath: _idFront!.path,
        idBackPath: _idBack!.path,
      );
      if (!mounted) return;
      if (result['statusCode'] == 200) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const VerificationWaitingScreen()),
          (route) => false,
        );
      } else {
        _showError(result['message'] as String? ?? 'Submission failed');
      }
    } catch (_) {
      if (mounted) _showError('Connection error. Try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.redAccent,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _green,
      appBar: AppBar(
        backgroundColor: _green,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Step 3: ID Verification',
            style: TextStyle(color: Colors.white, fontSize: 16)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const StepProgressBar(currentStep: 3),
              const SizedBox(height: 28),

              // ── ID Type ──────────────────────────────────────────────────
              _label('Select ID Type *'),
              _buildIdTypeRadio(),
              const SizedBox(height: 16),

              // ── ID Name ──────────────────────────────────────────────────
              _label('Choose ID *'),
              _idType == null
                  ? _disabledDropdown('Select ID type first')
                  : _dropdown(
                      value: _idName,
                      hint: 'Select ID',
                      items: _idOptions,
                      onChanged: (v) => setState(() => _idName = v),
                    ),
              const SizedBox(height: 24),

              // ── Front ID ─────────────────────────────────────────────────
              _label('Front of ID *'),
              _buildScanTile(
                isFront: true,
                bytes: _idFrontBytes,
                onScan: () => _scanId(isFront: true),
                onClear: () => setState(() { _idFront = null; _idFrontBytes = null; }),
              ),
              const SizedBox(height: 14),

              // ── Back ID ──────────────────────────────────────────────────
              _label('Back of ID *'),
              _buildScanTile(
                isFront: false,
                bytes: _idBackBytes,
                onScan: () => _scanId(isFront: false),
                onClear: () => setState(() { _idBack = null; _idBackBytes = null; }),
              ),
              const SizedBox(height: 16),

              // Image requirements
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tips for a clear scan:',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text(
                      '• Place ID on a dark flat surface\n'
                      '• All 4 corners must be visible\n'
                      '• Avoid glare — no flash\n'
                      '• Text must be legible',
                      style: TextStyle(color: Colors.white54, fontSize: 11, height: 1.6),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Submit
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: (_canSubmit && !_isLoading) ? _handleSubmit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _canSubmit ? _lime : Colors.white24,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: Colors.white24,
                    disabledForegroundColor: Colors.white38,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(32)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.black54))
                      : const Text('Submit for Verification',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ── Scan tile ────────────────────────────────────────────────────────────────

  Widget _buildScanTile({
    required bool isFront,
    required Uint8List? bytes,
    required VoidCallback onScan,
    required VoidCallback onClear,
  }) {
    if (bytes != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.memory(
              bytes,
              width: double.infinity,
              height: 160,
              fit: BoxFit.cover,
            ),
          ),
          // Captured badge
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded, color: Color(0xFF4CFF4C), size: 14),
                  SizedBox(width: 5),
                  Text('Captured', style: TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
            ),
          ),
          // Re-scan button
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: onScan,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                    color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.replay_rounded, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: onScan,
      child: Container(
        width: double.infinity,
        height: 130,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white30, style: BorderStyle.solid, width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.credit_card_rounded, color: Colors.white54, size: 36),
            const SizedBox(height: 10),
            const Text('Tap to scan',
                style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(
              isFront ? 'Hold ID front-facing to camera' : 'Flip ID and scan the back',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  Widget _buildIdTypeRadio() {
    return Column(children: [
      _radioTile(title: 'Primary ID', subtitle: '1 required', value: 'primary'),
      const SizedBox(height: 8),
      _radioTile(title: 'Secondary ID', subtitle: '2 required', value: 'secondary'),
    ]);
  }

  Widget _radioTile({required String title, required String subtitle, required String value}) {
    final isSelected = _idType == value;
    return GestureDetector(
      onTap: () => setState(() { _idType = value; _idName = null; }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isSelected ? Colors.white : Colors.white24, width: 1.5),
        ),
        child: Row(children: [
          Icon(
            isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
            color: isSelected ? const Color(0xFF1A6B1A) : Colors.white54,
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: TextStyle(
                    color: isSelected ? const Color(0xFF1A6B1A) : Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
            Text(subtitle,
                style: TextStyle(
                    color: isSelected ? Colors.black45 : Colors.white54,
                    fontSize: 11)),
          ]),
        ]),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 6),
        child: Text(text,
            style: const TextStyle(
                color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
      );


  Widget _dropdown({
    required String? value,
    required String hint,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      onChanged: onChanged,
      dropdownColor: Colors.white,
      isExpanded: true,
      style: const TextStyle(
          color: Color(0xFF1A6B1A), fontSize: 14, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF7BAE7B), fontSize: 14),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
      ),
      items: items
          .map((e) => DropdownMenuItem(
              value: e,
              child: Text(e, style: const TextStyle(color: Color(0xFF1A6B1A)))))
          .toList(),
    );
  }

  Widget _disabledDropdown(String hint) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Text(hint, style: const TextStyle(color: Colors.white38, fontSize: 14)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Live camera scanner page  (full-screen, GCash-style card frame)
// ─────────────────────────────────────────────────────────────────────────────

class _IdCameraPage extends StatefulWidget {
  final String label;
  const _IdCameraPage({required this.label});

  @override
  State<_IdCameraPage> createState() => _IdCameraPageState();
}

class _IdCameraPageState extends State<_IdCameraPage>
    with SingleTickerProviderStateMixin {
  CameraController? _ctrl;
  bool _cameraReady = false;
  bool _captured = false;
  bool _validating = false;
  String? _validationError;
  XFile? _photo;
  Uint8List? _photoBytes;

  late AnimationController _cornerAnim;

  // Philippine IDs always contain these keywords
  static const _phIdKeywords = [
    'republic of the philippines',
    'republika ng pilipinas',
    'philippine',
    'pilipinas',
    'lto',
    'ltfrb',
    'philhealth',
    'pag-ibig',
    'pagibig',
    'sss',
    'gsis',
    'umid',
    'comelec',
    'prc',
    'passport',
    'driver',
    'license',
    'voter',
    'postal',
    'national id',
    'philid',
    'senior citizen',
    'pwd',
    'date of birth',
    'birthday',
    'nationality',
    'address',
    'signature',
    'valid until',
    'expiry',
    'expiration',
  ];

  @override
  void initState() {
    super.initState();
    _cornerAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      _ctrl = CameraController(back, ResolutionPreset.high, enableAudio: false);
      await _ctrl!.initialize();
      if (mounted) setState(() => _cameraReady = true);
    } catch (_) {}
  }

  Future<void> _capture() async {
    if (!_cameraReady || _captured || _validating) return;
    setState(() { _validating = true; _validationError = null; });

    try {
      final photo = await _ctrl!.takePicture();
      final bytes = await photo.readAsBytes();

      // ── PH ID text detection ──────────────────────────────────────────────
      final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final inputImage = InputImage.fromFilePath(photo.path);
      final recognized = await recognizer.processImage(inputImage);
      await recognizer.close();

      final fullText = recognized.text.toLowerCase();
      final totalChars = fullText.replaceAll(RegExp(r'\s'), '').length;

      // Check for PH ID keyword OR enough text content (≥40 chars of non-space)
      final hasKeyword = _phIdKeywords.any((kw) => fullText.contains(kw));
      final hasEnoughText = totalChars >= 40;

      if (!hasKeyword && !hasEnoughText) {
        if (mounted) {
          setState(() {
            _validating = false;
            _validationError = 'No valid ID detected.\nMake sure your ID fits inside the frame\nand is clearly visible.';
          });
        }
        return;
      }
      // ─────────────────────────────────────────────────────────────────────

      if (!mounted) return;
      setState(() {
        _photo = photo;
        _photoBytes = bytes;
        _captured = true;
        _validating = false;
        _validationError = null;
      });
    } catch (_) {
      if (mounted) setState(() => _validating = false);
    }
  }

  void _retake() {
    setState(() {
      _photo = null;
      _photoBytes = null;
      _captured = false;
      _validating = false;
      _validationError = null;
    });
  }

  void _usePhoto() {
    Navigator.pop(context, _photo);
  }

  @override
  void dispose() {
    _cornerAnim.dispose();
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
          // Camera / preview
          if (_cameraReady && !_captured)
            SizedBox.expand(child: CameraPreview(_ctrl!)),
          if (_captured && _photoBytes != null)
            Image.memory(_photoBytes!, fit: BoxFit.cover, width: size.width, height: size.height),

          // Card frame overlay
          if (!_captured)
            AnimatedBuilder(
              animation: _cornerAnim,
              builder: (_, __) => CustomPaint(
                size: size,
                painter: _CardFramePainter(cornerGlow: _cornerAnim.value),
              ),
            )
          else
            CustomPaint(
              size: size,
              painter: _CardFramePainter(cornerGlow: 1.0, captured: true),
            ),

          // UI chrome
          SafeArea(
            child: Column(
              children: [
                // Top bar
                Row(children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                  const Spacer(),
                  Text(
                    widget.label,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ]),

                const Spacer(),

                // Instruction / validation error
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: _validationError != null
                        ? Colors.red.withValues(alpha: 0.75)
                        : Colors.black54,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    _validationError ??
                        (_validating
                            ? 'Checking ID…'
                            : _captured
                                ? 'Check that all details are clear'
                                : 'Fit your Philippine ID within the frame'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
                  ),
                ),

                const SizedBox(height: 28),

                // Buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _captured
                      ? Row(children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _retake,
                              icon: const Icon(Icons.replay_rounded,
                                  color: Colors.white70, size: 18),
                              label: const Text('Retake',
                                  style: TextStyle(color: Colors.white70)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white30),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(32)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: _usePhoto,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4CFF4C),
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(32)),
                              ),
                              child: const Text('Use This Photo',
                                  style: TextStyle(
                                      fontSize: 15, fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ])
                      : SizedBox(
                          width: double.infinity,
                          height: 64,
                          child: _validating
                              ? const Center(
                                  child: SizedBox(
                                    width: 40,
                                    height: 40,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 3, color: Colors.white),
                                  ),
                                )
                              : GestureDetector(
                                  onTap: _cameraReady ? _capture : null,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border:
                                          Border.all(color: Colors.white, width: 4),
                                    ),
                                    child: Center(
                                      child: Container(
                                        width: 52,
                                        height: 52,
                                        decoration: const BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle),
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card frame painter — dark overlay + rounded rect cutout + corner markers
// ─────────────────────────────────────────────────────────────────────────────

class _CardFramePainter extends CustomPainter {
  final double cornerGlow; // 0..1
  final bool captured;

  const _CardFramePainter({required this.cornerGlow, this.captured = false});

  @override
  void paint(Canvas canvas, Size size) {
    const cardAspect = 1.586; // standard ID card ratio
    final cardW = size.width * 0.86;
    final cardH = cardW / cardAspect;
    final cardRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(size.width / 2, size.height * 0.44),
          width: cardW,
          height: cardH),
      const Radius.circular(14),
    );

    // Dark overlay with card hole
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(cardRect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, Paint()..color = Colors.black.withValues(alpha: 0.65));

    // Card border
    final borderColor = captured
        ? const Color(0xFF4CFF4C)
        : Color.lerp(Colors.white54, Colors.white, cornerGlow)!;
    canvas.drawRRect(
      cardRect,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Corner markers
    final r = cardRect.outerRect;
    final markerColor = captured
        ? const Color(0xFF4CFF4C)
        : Color.lerp(Colors.white70, Colors.white, cornerGlow)!;
    _drawCorners(canvas, r, markerColor);
  }

  void _drawCorners(Canvas canvas, Rect r, Color color) {
    const len = 22.0;
    const thick = 3.5;
    final p = Paint()
      ..color = color
      ..strokeWidth = thick
      ..strokeCap = StrokeCap.round;

    // Top-left
    canvas.drawLine(r.topLeft, r.topLeft.translate(len, 0), p);
    canvas.drawLine(r.topLeft, r.topLeft.translate(0, len), p);
    // Top-right
    canvas.drawLine(r.topRight, r.topRight.translate(-len, 0), p);
    canvas.drawLine(r.topRight, r.topRight.translate(0, len), p);
    // Bottom-left
    canvas.drawLine(r.bottomLeft, r.bottomLeft.translate(len, 0), p);
    canvas.drawLine(r.bottomLeft, r.bottomLeft.translate(0, -len), p);
    // Bottom-right
    canvas.drawLine(r.bottomRight, r.bottomRight.translate(-len, 0), p);
    canvas.drawLine(r.bottomRight, r.bottomRight.translate(0, -len), p);
  }

  @override
  bool shouldRepaint(_CardFramePainter old) =>
      old.cornerGlow != cornerGlow || old.captured != captured;
}
