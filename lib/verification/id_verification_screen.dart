import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import 'step_progress_bar.dart';
import 'verification_waiting_screen.dart';

class IdVerificationScreen extends StatefulWidget {
  final String? facePhotoPath;

  const IdVerificationScreen({super.key, this.facePhotoPath});

  @override
  State<IdVerificationScreen> createState() => _IdVerificationScreenState();
}

class _IdVerificationScreenState extends State<IdVerificationScreen> {
  static const Color _green = Color(0xFF1A6B1A);
  static const Color _limeGreen = Color(0xFF4CFF4C);

  String? _idType; // 'primary' | 'secondary'
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

  Future<void> _pickImage(bool isFront) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Text(isFront ? 'Upload Front of ID' : 'Upload Back of ID',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: Color(0xFF1A6B1A)),
              title: const Text('Take Photo'),
              onTap: () async {
                Navigator.pop(context);
                final f = await ImagePicker()
                    .pickImage(source: ImageSource.camera, imageQuality: 90);
                if (f != null) _checkAndSetIdImage(f, isFront);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: Color(0xFF1A6B1A)),
              title: const Text('Choose from Gallery'),
              onTap: () async {
                Navigator.pop(context);
                final f = await ImagePicker()
                    .pickImage(source: ImageSource.gallery, imageQuality: 90);
                if (f != null) _checkAndSetIdImage(f, isFront);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _checkAndSetIdImage(XFile file, bool isFront) async {
    final bytes = await file.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Image too large (max 5MB)'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ));
      }
      return;
    }
    setState(() {
      if (isFront) {
        _idFront = file;
        _idFrontBytes = bytes;
      } else {
        _idBack = file;
        _idBackBytes = bytes;
      }
    });
  }

  bool get _canSubmit =>
      _idType != null && _idName != null && _idFront != null && _idBack != null;

  Future<void> _handleSubmit() async {
    if (!_canSubmit) {
      _showError('Please complete all required fields');
      return;
    }

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

              // ID Type — radio buttons
              _label('Select ID Type *'),
              _buildIdTypeRadio(),
              const SizedBox(height: 16),

              // ID Name dropdown (only if type selected)
              _label('Choose ID *'),
              _idType == null
                  ? _disabledDropdown('Select ID type first')
                  : _dropdown(
                      value: _idName,
                      hint: 'Select ID',
                      items: _idOptions,
                      onChanged: (v) => setState(() => _idName = v),
                    ),
              const SizedBox(height: 16),

              // ID Front
              _label('Front of ID *'),
              _buildImageUpload(isFront: true),
              const SizedBox(height: 14),

              // ID Back
              _label('Back of ID *'),
              _buildImageUpload(isFront: false),
              const SizedBox(height: 12),

              // Image quality note
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
                    Text('Image Requirements:',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text(
                      '• Clear and legible text\n• No glare or shadows\n• All 4 corners visible\n• Good lighting',
                      style: TextStyle(color: Colors.white54, fontSize: 11, height: 1.6),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: (_canSubmit && !_isLoading) ? _handleSubmit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _canSubmit ? _limeGreen : Colors.white24,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: Colors.white24,
                    disabledForegroundColor: Colors.white38,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(32)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.black54))
                      : const Text('Submit for Verification',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIdTypeRadio() {
    return Column(
      children: [
        _radioTile(
          title: 'Primary ID',
          subtitle: '1 required',
          value: 'primary',
        ),
        const SizedBox(height: 8),
        _radioTile(
          title: 'Secondary ID',
          subtitle: '2 required',
          value: 'secondary',
        ),
      ],
    );
  }

  Widget _radioTile({
    required String title,
    required String subtitle,
    required String value,
  }) {
    final isSelected = _idType == value;
    return GestureDetector(
      onTap: () => setState(() {
        _idType = value;
        _idName = null; // reset when type changes
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isSelected ? Colors.white : Colors.white24, width: 1.5),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? _green : Colors.white54,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: isSelected ? _green : Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                Text(subtitle,
                    style: TextStyle(
                        color: isSelected ? Colors.black45 : Colors.white54,
                        fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageUpload({required bool isFront}) {
    final file = isFront ? _idFront : _idBack;
    final bytes = isFront ? _idFrontBytes : _idBackBytes;
    return GestureDetector(
      onTap: () => _pickImage(isFront),
      child: Container(
        width: double.infinity,
        height: 140,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: file != null ? Colors.greenAccent.withValues(alpha: 0.5) : Colors.white30,
              width: 1.5),
        ),
        child: file == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt_outlined,
                      color: Colors.white54, size: 32),
                  const SizedBox(height: 8),
                  const Text('Tap to upload',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const Text('JPG, PNG  •  Max 5MB',
                      style: TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.memory(bytes!, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 6, right: 6,
                    child: GestureDetector(
                      onTap: () => setState(() {
                        if (isFront) _idFront = null;
                        else _idBack = null;
                      }),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                            color: Colors.black54, shape: BoxShape.circle),
                        child: const Icon(Icons.close, color: Colors.white, size: 14),
                      ),
                    ),
                  ),
                ],
              ),
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
      style: const TextStyle(color: _green, fontSize: 14, fontWeight: FontWeight.w600),
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
              value: e, child: Text(e, style: const TextStyle(color: _green))))
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
      child: Text(hint,
          style: const TextStyle(color: Colors.white38, fontSize: 14)),
    );
  }
}
