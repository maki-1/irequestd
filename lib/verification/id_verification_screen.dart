import 'dart:math' as math;
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img_lib;
import '../login_screen.dart';
import '../services/api_service.dart';
import '../services/llama_service.dart';
import 'step_progress_bar.dart';
import 'face_recognition_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public entry point
// ─────────────────────────────────────────────────────────────────────────────

class IdVerificationScreen extends StatefulWidget {
  const IdVerificationScreen({super.key});

  @override
  State<IdVerificationScreen> createState() => _IdVerificationScreenState();
}

class _IdVerificationScreenState extends State<IdVerificationScreen> {
  static const Color _green = Color(0xFF1A6B1A);
  static const Color _lime = Color(0xFF4CFF4C);

  // IDs that only have a front (no back side needed)
  static const _singlePageIds = {
    'Philippine Passport',
    'NBI Clearance',
    'Police Clearance',
    'PSA Birth Certificate',
    'Marriage Certificate',
  };

  String _registeredName = '';
  String? _idType;

  // First ID
  String? _idName;
  XFile? _idFront;
  XFile? _idBack;
  Uint8List? _idFrontBytes;
  Uint8List? _idBackBytes;
  Uint8List? _idFaceCrop;

  // Second ID (secondary type only)
  String? _idName2;
  XFile? _idFront2;
  XFile? _idBack2;
  Uint8List? _idFrontBytes2;
  Uint8List? _idBackBytes2;

  bool get _needsBack => !_singlePageIds.contains(_idName);
  bool get _needsBack2 => !_singlePageIds.contains(_idName2);

  // Secondary IDs available for the second slot (excludes already-chosen first ID)
  List<String> get _secondIdOptions =>
      _secondaryIds.where((id) => id != _idName).toList();

  @override
  void initState() {
    super.initState();
    _loadRegisteredName();
  }

  Future<void> _loadRegisteredName() async {
    try {
      // fullName is stored in the demographic profile, not the basic user object
      final profile = await ApiService.fetchDemographicProfile();
      if (mounted) {
        setState(() => _registeredName = (profile['fullName'] as String? ?? '').trim());
      }
    } catch (_) {
      // fallback to basic user object
      final user = await ApiService.getUser();
      if (user != null && mounted) {
        setState(() => _registeredName = (user['fullName'] as String? ?? '').trim());
      }
    }
  }

  static const _primaryIds = [
    'Philippine National ID',
    'Philippine Passport',
    "Driver's License",
    'Postal ID',
    "Voter's ID",
    'Senior PWD ID',
  ];

  static const _secondaryIds = [
    'TIN ID',
    'PhilHealth ID',
    'Pagibig Loyalty Card',
    'NBI Clearance',
    'Police Clearance',
    'Company ID',
    'School ID',
    'PSA Birth Certificate',
    'Marriage Certificate',
  ];

  List<String> get _idOptions =>
      _idType == 'primary' ? _primaryIds : _secondaryIds;

  bool get _canSubmit {
    if (_idType == null || _idName == null || _idFront == null) return false;
    if (_needsBack && _idBack == null) return false;
    if (_idType == 'secondary') {
      if (_idName2 == null || _idFront2 == null) return false;
      if (_needsBack2 && _idBack2 == null) return false;
    }
    return true;
  }

  // Crops image bytes to the same 1.586:1 card frame aspect ratio used in the overlay.
  // The original file is unchanged — this is display-only.
  Uint8List _cropToCardFrame(Uint8List raw) {
    try {
      final decoded = img_lib.decodeImage(raw);
      if (decoded == null) return raw;
      const cardAspect = 1.586; // width / height — matches _CardFramePainter
      final w = decoded.width;
      final h = decoded.height;
      int cropW, cropH;
      if (w / h > cardAspect) {
        cropH = h;
        cropW = (h * cardAspect).toInt().clamp(1, w);
      } else {
        cropW = w;
        cropH = (w / cardAspect).toInt().clamp(1, h);
      }
      final x = (w - cropW) ~/ 2;
      final y = math.max(0, (h * 0.44 - cropH / 2).toInt()).clamp(0, h - cropH);
      final cropped = img_lib.copyCrop(decoded, x: x, y: y, width: cropW, height: cropH);
      return Uint8List.fromList(img_lib.encodeJpg(cropped));
    } catch (_) {
      return raw;
    }
  }

  // Open the live camera scanner and wait for a captured photo + optional face crop
  Future<void> _scanId({required bool isFront}) async {
    final result = await Navigator.push<(XFile, Uint8List?)?>(
      context,
      MaterialPageRoute(
        builder: (_) => _IdCameraPage(
          label: isFront ? 'Front of ID' : 'Back of ID',
          idName: _idName ?? '',
          detectFace: isFront,
          registeredName: _registeredName,
          isFront: isFront,
        ),
        fullscreenDialog: true,
      ),
    );
    if (result == null) return;
    final (photo, faceCrop) = result;
    final raw = await photo.readAsBytes();
    final displayBytes = _cropToCardFrame(raw);
    setState(() {
      if (isFront) {
        _idFront = photo;
        _idFrontBytes = displayBytes;
        _idFaceCrop = faceCrop;
      } else {
        _idBack = photo;
        _idBackBytes = displayBytes;
      }
    });
  }

  Future<void> _scanId2({required bool isFront}) async {
    final result = await Navigator.push<(XFile, Uint8List?)?>(
      context,
      MaterialPageRoute(
        builder: (_) => _IdCameraPage(
          label: isFront ? 'Front of 2nd ID' : 'Back of 2nd ID',
          idName: _idName2 ?? '',
          detectFace: false,
          registeredName: _registeredName,
          isFront: isFront,
        ),
        fullscreenDialog: true,
      ),
    );
    if (result == null) return;
    final (photo, _) = result;
    final raw = await photo.readAsBytes();
    final displayBytes = _cropToCardFrame(raw);
    setState(() {
      if (isFront) {
        _idFront2 = photo;
        _idFrontBytes2 = displayBytes;
      } else {
        _idBack2 = photo;
        _idBackBytes2 = displayBytes;
      }
    });
  }

  void _handleContinue() {
    if (!_canSubmit) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FaceRecognitionScreen(
          idType: _idType!,
          idName: _idName!,
          idFrontPath: _idFront!.path,
          idBackPath: _idBack?.path ?? '',
          idFaceCrop: _idFaceCrop,
          idFrontBytes: _idFrontBytes,
          idName2: _idName2,
          idFrontPath2: _idFront2?.path,
          idBackPath2: _idBack2?.path,
        ),
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.redAccent,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
            'Your progress is saved. You can continue from this step when you log back in.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ApiService.clearSession();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
    }
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
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Logout',
            onPressed: _confirmLogout,
          ),
        ],
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
                      onChanged: (v) => setState(() {
                        _idName = v;
                        _idFront = null; _idFrontBytes = null;
                        _idBack = null; _idBackBytes = null;
                        _idFaceCrop = null;
                      }),
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

              // ── Back ID (hidden for single-page IDs) ─────────────────────
              if (_needsBack) ...[
                _label('Back of ID *'),
                _buildScanTile(
                  isFront: false,
                  bytes: _idBackBytes,
                  onScan: () => _scanId(isFront: false),
                  onClear: () => setState(() { _idBack = null; _idBackBytes = null; }),
                ),
                const SizedBox(height: 16),
              ],

              // ── Second ID (secondary type only) ──────────────────────────
              if (_idType == 'secondary') ...[
                const Divider(color: Colors.white24, thickness: 1, height: 32),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: Colors.white54, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Secondary ID requires 2 valid IDs.',
                          style: TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _label('2nd ID *'),
                _idName == null
                    ? _disabledDropdown('Select your 1st ID first')
                    : _dropdown(
                        value: _idName2,
                        hint: 'Select 2nd ID',
                        items: _secondIdOptions,
                        onChanged: (v) => setState(() {
                          _idName2 = v;
                          _idFront2 = null; _idFrontBytes2 = null;
                          _idBack2 = null; _idBackBytes2 = null;
                        }),
                      ),
                const SizedBox(height: 14),
                _label('Front of 2nd ID *'),
                _buildScanTile(
                  isFront: true,
                  bytes: _idFrontBytes2,
                  onScan: () => _scanId2(isFront: true),
                  onClear: () => setState(() { _idFront2 = null; _idFrontBytes2 = null; }),
                ),
                const SizedBox(height: 14),
                if (_needsBack2) ...[
                  _label('Back of 2nd ID *'),
                  _buildScanTile(
                    isFront: false,
                    bytes: _idBackBytes2,
                    onScan: () => _scanId2(isFront: false),
                    onClear: () => setState(() { _idBack2 = null; _idBackBytes2 = null; }),
                  ),
                  const SizedBox(height: 16),
                ],
              ],

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
                  onPressed: _canSubmit ? _handleContinue : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _canSubmit ? _lime : Colors.white24,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: Colors.white24,
                    disabledForegroundColor: Colors.white38,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(32)),
                    elevation: 0,
                  ),
                  child: const Text('Continue to Face Scan',
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
      onTap: () => setState(() {
        _idType = value;
        _idName = null;
        _idFront = null; _idFrontBytes = null;
        _idBack = null; _idBackBytes = null;
        _idFaceCrop = null;
        _idName2 = null;
        _idFront2 = null; _idFrontBytes2 = null;
        _idBack2 = null; _idBackBytes2 = null;
      }),
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
  final String idName;
  final bool detectFace;
  final String registeredName;
  final bool isFront;
  const _IdCameraPage({
    required this.label,
    required this.idName,
    this.detectFace = false,
    this.registeredName = '',
    this.isFront = true,
  });

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
  Uint8List? _idFaceCrop; // cropped face from ID (front only)

  late AnimationController _cornerAnim;

  // Keywords specific to each ID type — OCR must match at least one
  static const _idKeywords = <String, List<String>>{
    'Philippine National ID': [
      'pambansang pagkakakilanlan',
      'philippine identification card',
      'philsys',
      'psn',
      'psa.gov.ph',
    ],
    'Philippine Passport': [
      'pasaporte',
      'passport',
      'republika ng pilipinas',
      'dfa',
      'p<phl',
    ],
    "Driver's License": [
      'land transportation office',
      'professional driver',
      'department of transportation',
      'g v w',
      'agency code',
    ],
    'Postal ID': [
      'phlpost',
      'philippine postal corporation',
      'postal identity card',
      'prn',
    ],
    // Voter's ID and Senior PWD ID must contain 'bukidnon' since these
    // are locally issued and vary widely — the municipality name is the
    // most reliable unique identifier for Barangay Dologon residents.
    "Voter's ID": [
      'comelec',
      'commission on elections',
      'bukidnon',
    ],
    'Senior PWD ID': [
      'senior citizen',
      'pwd',
      'person with disability',
      'bukidnon',
    ],
    'TIN ID': [
      'bureau of internal revenue',
      'digital tin id',
      'department of finance',
      'rdo',
      'bir',
    ],
    'PhilHealth ID': [
      'philippine health insurance corporation',
      'national health insurance program',
      'philhealth',
      'informal economy',
    ],
    'Pagibig Loyalty Card': [
      'pag-ibig',
      'loyalty card',
      'mid no',
      'pagibig',
    ],
    'NBI Clearance': [
      'national bureau of investigation',
      'multi-purpose clearance',
      'department of justice',
      'nbi',
    ],
    'Police Clearance': [
      'national police clearance',
      'philippine national police',
      'thumbmark',
      'pnpclearance.ph',
    ],
    'Company ID': [
      'employee id',
      'company id',
      'employment id',
      'employee no',
    ],
    'School ID': [
      'university',
      'college',
      'academy',
      'institute',
      'school id',
      'student',
    ],
    'PSA Birth Certificate': [
      'certificate of live birth',
      'philippine statistics authority',
      'birth certificate',
      'psa',
    ],
    'Marriage Certificate': [
      'marriage certificate',
      'philippine statistics authority',
      'psa',
    ],
  };

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

  // Returns true if enough name parts from [registeredName] appear in [ocrText].
  // Short names (≤3 parts): ALL must match.
  // Longer names (4+ parts): all minus 1, allowing for an abbreviated middle name.
  bool _nameFoundInOcr(String registeredName, String ocrText) {
    final tokens = registeredName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z\s]'), '')
        .split(RegExp(r'\s+'))
        .where((t) => t.length > 2) // skip single initials and tiny words
        .toList();

    if (tokens.isEmpty) return false; // can't verify — reject

    final ocrNorm = ocrText.toLowerCase().replaceAll(RegExp(r'[^a-z\s]'), '');
    final matched = tokens.where((t) => ocrNorm.contains(t)).length;

    // Short names: all tokens must match
    // Longer names: allow 1 miss (e.g. middle name abbreviated on ID)
    final required = tokens.length <= 3 ? tokens.length : tokens.length - 1;
    return matched >= required;
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

      // Step 1 — make sure something was scanned at all
      if (totalChars < 20) {
        if (mounted) {
          setState(() {
            _validating = false;
            _validationError = 'No ID detected.\nMake sure your ID fits inside the frame\nand is clearly visible.';
          });
        }
        return;
      }

      // Step 2 — verify it matches the selected ID type
      if (widget.idName == 'School ID' || widget.idName == 'Company ID') {
        // No fixed keywords for these — but reject if definitive keywords from
        // OTHER known ID types are found in the scan.
        const _otherIdKeywords = [
          'phlpost', 'philippine postal corporation', 'postal identity card',
          'land transportation office', 'professional driver',
          'pasaporte', 'passport', 'p<phl',
          'pambansang pagkakakilanlan', 'philippine identification card', 'philsys',
          'philhealth', 'philippine health insurance corporation',
          'pag-ibig', 'pagibig', 'loyalty card', 'mid no',
          'bureau of internal revenue', 'digital tin id',
          'national bureau of investigation', 'multi-purpose clearance',
          'national police clearance', 'philippine national police',
          'comelec', 'commission on elections',
          'senior citizen', 'osca',
          'certificate of live birth', 'birth certificate',
          'marriage certificate',
        ];
        final hasOtherIdKeyword = _otherIdKeywords.any((kw) => fullText.contains(kw));
        if (hasOtherIdKeyword) {
          if (mounted) {
            setState(() {
              _validating = false;
              _validationError = 'This does not appear to be a ${widget.idName}.\nPlease scan the correct ID.';
            });
          }
          return;
        }
      } else {
        final expectedKeywords = _idKeywords[widget.idName] ?? [];
        final matchesType = expectedKeywords.any((kw) => fullText.contains(kw));
        if (!matchesType) {
          if (mounted) {
            setState(() {
              _validating = false;
              _validationError = 'This does not look like a ${widget.idName}.\nPlease scan the correct ID.';
            });
          }
          return;
        }
      }

      // Step 3 — name presence check
      // Front: registered name must appear (it's printed on the front of the ID).
      // Back:  if the registered name appears in the OCR, the user scanned the
      //        front again instead of flipping the ID.
      if (widget.registeredName.isNotEmpty) {
        final nameFound = _nameFoundInOcr(widget.registeredName, fullText);
        if (widget.isFront && !nameFound) {
          if (mounted) {
            setState(() {
              _validating = false;
              _validationError = 'The name on this ID does not match\nyour registered name.\nPlease use your own ID.';
            });
          }
          return;
        } else if (!widget.isFront && nameFound) {
          if (mounted) {
            setState(() {
              _validating = false;
              _validationError = 'This appears to be the front of the ID.\nPlease flip the ID and scan the back side.';
            });
          }
          return;
        }
      }

      // Step 4 — LLaMA Vision enhanced check
      if (widget.detectFace) {
        // Front scan: cross-check ID type and name
        final llama = await LlamaService.analyzeId(bytes);

        debugPrint('[LLaMA] success=${llama.success} idType=${llama.idType} name=${llama.fullName} side=${llama.side}');
        debugPrint('[Name check] registered="${widget.registeredName}"');

        if (llama.success) {
          if (llama.idType != 'Unknown' && llama.idType != widget.idName) {
            if (mounted) {
              setState(() {
                _validating = false;
                _validationError = 'This looks like a ${llama.idType},\nnot a ${widget.idName}.\nPlease scan the correct ID.';
              });
            }
            return;
          }
          if (widget.registeredName.isNotEmpty && llama.fullName.isNotEmpty) {
            debugPrint('[LLaMA] name on ID: "${llama.fullName}"');
            if (!_nameFoundInOcr(widget.registeredName, llama.fullName.toLowerCase())) {
              if (mounted) {
                setState(() {
                  _validating = false;
                  _validationError = 'The name on this ID does not match\nyour registered name.\nPlease use your own ID.';
                });
              }
              return;
            }
          }
        } else {
          debugPrint('[LLaMA] call failed — falling back to ML Kit OCR check only');
        }
      } else if (!widget.isFront) {
        // Back scan: use LLaMA to confirm this is actually the back of the ID
        final llama = await LlamaService.analyzeId(bytes);
        debugPrint('[LLaMA back] success=${llama.success} side=${llama.side}');
        if (llama.success && llama.side == 'front') {
          if (mounted) {
            setState(() {
              _validating = false;
              _validationError = 'This appears to be the front of the ID.\nPlease flip the ID and scan the back side.';
            });
          }
          return;
        }
      }
      // ─────────────────────────────────────────────────────────────────────

      // ── Face detection & crop (front of ID only) ─────────────────────
      if (widget.detectFace) {
        try {
          final faceDetector = FaceDetector(options: FaceDetectorOptions());
          final faceInput = InputImage.fromFilePath(photo.path);
          final faces = await faceDetector.processImage(faceInput);
          await faceDetector.close();

          if (faces.isNotEmpty) {
            final bbox = faces.first.boundingBox;
            final decoded = img_lib.decodeImage(bytes);
            if (decoded != null) {
              final x = bbox.left.toInt().clamp(0, decoded.width - 1);
              final y = bbox.top.toInt().clamp(0, decoded.height - 1);
              final w = bbox.width.toInt().clamp(1, decoded.width - x);
              final h = bbox.height.toInt().clamp(1, decoded.height - y);
              final cropped = img_lib.copyCrop(decoded, x: x, y: y, width: w, height: h);
              _idFaceCrop = Uint8List.fromList(img_lib.encodeJpg(cropped));
            }
          }
        } catch (_) {
          // face detection is best-effort — don't block the scan
        }
      }
      // ─────────────────────────────────────────────────────────────────

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
    Navigator.pop(context, (_photo!, _idFaceCrop));
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
                            ? 'Verifying ID…'
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
