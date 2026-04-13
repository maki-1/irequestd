import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import 'step_progress_bar.dart';
import 'face_recognition_screen.dart';

class EducationScreen extends StatefulWidget {
  const EducationScreen({super.key});

  @override
  State<EducationScreen> createState() => _EducationScreenState();
}

class _EducationScreenState extends State<EducationScreen> {
  static const Color _green = Color(0xFF1A6B1A);
  static const Color _limeGreen = Color(0xFF4CFF4C);

  final _schoolController = TextEditingController();
  final _yearController = TextEditingController();
  final _courseController = TextEditingController();

  String? _educationLevel;
  XFile? _certFile;
  Uint8List? _certBytes;
  bool _isLoading = false;

  static const _levels = [
    'Elementary',
    'High School',
    'Vocational',
    "Bachelor's Degree",
    "Master's Degree",
    'PhD',
    'Other',
  ];

  @override
  void dispose() {
    _schoolController.dispose();
    _yearController.dispose();
    _courseController.dispose();
    super.dispose();
  }

  Future<void> _pickCertificate() async {
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
            const Text('Upload Certificate',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: Color(0xFF1A6B1A)),
              title: const Text('Take Photo'),
              onTap: () async {
                Navigator.pop(context);
                final file = await ImagePicker()
                    .pickImage(source: ImageSource.camera, imageQuality: 85);
                if (file != null) _checkAndSetFile(file);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: Color(0xFF1A6B1A)),
              title: const Text('Choose from Gallery'),
              onTap: () async {
                Navigator.pop(context);
                final file = await ImagePicker()
                    .pickImage(source: ImageSource.gallery, imageQuality: 85);
                if (file != null) _checkAndSetFile(file);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _checkAndSetFile(XFile file) async {
    final bytes = await file.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('File too large (max 5MB)'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ));
      }
      return;
    }
    setState(() {
      _certFile = file;
      _certBytes = bytes;
    });
  }

  Future<void> _handleContinue() async {
    final year = _yearController.text.trim();
    if (year.isNotEmpty) {
      final y = int.tryParse(year);
      if (y == null || y < 1950 || y > 2035) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Year must be between 1950 and 2035'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ));
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      final result = await ApiService.submitStep2(
        {
          'educationLevel': _educationLevel ?? '',
          'school': _schoolController.text.trim(),
          'yearGraduated': year,
          'course': _courseController.text.trim(),
        },
        _certFile?.path,
      );

      if (!mounted) return;

      if (result['statusCode'] == 200) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FaceRecognitionScreen()),
        );
      } else {
        _showError(result['message'] as String? ?? 'Failed to save');
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
        title: const Text('Step 2: Educational Attainment',
            style: TextStyle(color: Colors.white, fontSize: 16)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const StepProgressBar(currentStep: 2),
              const SizedBox(height: 28),

              _label('Highest Education Level'),
              _dropdown(
                value: _educationLevel,
                hint: 'Select',
                items: _levels,
                onChanged: (v) => setState(() => _educationLevel = v),
              ),
              const SizedBox(height: 14),

              _label('School / Institution'),
              _textField(
                controller: _schoolController,
                hint: 'Name of school',
                maxLength: 150,
              ),
              const SizedBox(height: 14),

              _label('Year Graduated / Enrolled'),
              _textField(
                controller: _yearController,
                hint: 'e.g., 2020',
                keyboardType: TextInputType.number,
                formatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
              ),
              const SizedBox(height: 14),

              _label('Course / Strand'),
              _textField(
                controller: _courseController,
                hint: 'If applicable',
                maxLength: 100,
              ),
              const SizedBox(height: 14),

              _label('Educational Certificate (Optional)'),
              _buildFileUpload(),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _limeGreen,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(32)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.black54))
                      : const Text('Continue to Step 3',
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

  Widget _buildFileUpload() {
    return GestureDetector(
      onTap: _pickCertificate,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white30, width: 1.5),
        ),
        child: _certFile == null
            ? const Column(
                children: [
                  Icon(Icons.upload_file_rounded, color: Colors.white54, size: 36),
                  SizedBox(height: 8),
                  Text('Tap to upload (Optional)',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                  SizedBox(height: 4),
                  Text('PDF, JPG, PNG  •  Max 5MB',
                      style: TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              )
            : Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(_certBytes!,
                        height: 100, fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 8),
                  Text(_certFile!.name,
                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  TextButton.icon(
                    onPressed: () => setState(() => _certFile = null),
                    icon: const Icon(Icons.close, size: 14, color: Colors.redAccent),
                    label: const Text('Remove',
                        style: TextStyle(color: Colors.redAccent, fontSize: 12)),
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

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    int? maxLength,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? formatters,
  }) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      keyboardType: keyboardType,
      inputFormatters: formatters,
      style: const TextStyle(color: _green, fontSize: 15, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF7BAE7B), fontSize: 14),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
        counterStyle: const TextStyle(color: Colors.white54, fontSize: 10),
      ),
    );
  }

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
      style: const TextStyle(color: _green, fontSize: 15, fontWeight: FontWeight.w600),
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
          .map((e) =>
              DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(color: _green))))
          .toList(),
    );
  }
}
