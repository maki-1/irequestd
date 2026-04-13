import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'step_progress_bar.dart';
import 'verification_waiting_screen.dart';

class FaceRecognitionScreen extends StatefulWidget {
  const FaceRecognitionScreen({super.key});

  @override
  State<FaceRecognitionScreen> createState() => _FaceRecognitionScreenState();
}

class _FaceRecognitionScreenState extends State<FaceRecognitionScreen> {
  static const Color _green = Color(0xFF1A6B1A);
  static const Color _limeGreen = Color(0xFF4CFF4C);
  static const Color _gold = Color(0xFFFFD700);

  XFile? _facePhoto;
  Uint8List? _facePhotoBytes;

  Future<void> _capturePhoto() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 90,
    );
    if (file != null) {
      final bytes = await file.readAsBytes();
      setState(() {
        _facePhoto = file;
        _facePhotoBytes = bytes;
      });
    }
  }

  void _handleContinue() {
    if (_facePhoto == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please take a selfie to continue'),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    _goNext();
  }

  void _goNext() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const VerificationWaitingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _green,
      appBar: AppBar(
        backgroundColor: _green,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Face Recognition',
            style: TextStyle(color: Colors.white, fontSize: 16)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const StepProgressBar(currentStep: 3),
              const SizedBox(height: 32),

              // Camera preview / photo area
              GestureDetector(
                onTap: _facePhoto == null ? _capturePhoto : null,
                child: Container(
                  width: double.infinity,
                  height: 240,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24, width: 2),
                  ),
                  child: _facePhoto == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white54, width: 2),
                              ),
                              child: const Icon(Icons.face_rounded,
                                  color: Colors.white38, size: 60),
                            ),
                            const SizedBox(height: 16),
                            const Text('Position your face in the frame',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 13)),
                          ],
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.memory(
                            _facePhotoBytes!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: 240,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),

              // Instructions
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _instruction(Icons.wb_sunny_outlined, 'Good lighting required'),
                    _instruction(Icons.remove_red_eye_outlined, 'No glasses or face coverings'),
                    _instruction(Icons.face_outlined, 'Face straight to camera'),
                    _instruction(Icons.center_focus_strong_outlined,
                        'Face fills the frame adequately'),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Skip button (beta)
              TextButton.icon(
                onPressed: _goNext,
                icon: const Icon(Icons.skip_next_rounded, color: Colors.white38, size: 18),
                label: const Text(
                  'Skip  (Beta)',
                  style: TextStyle(color: Colors.white38, fontSize: 13),
                ),
              ),
              const SizedBox(height: 8),

              // Capture button
              if (_facePhoto == null)
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: _capturePhoto,
                    icon: const Icon(Icons.camera_alt_rounded),
                    label: const Text('Start Capture',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _gold,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(32)),
                      elevation: 0,
                    ),
                  ),
                )
              else
                Column(
                  children: [
                    const Text('Capture successful ✓',
                        style: TextStyle(
                            color: Color(0xFF4CFF4C),
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _capturePhoto,
                            icon: const Icon(Icons.replay_rounded,
                                color: Colors.white70, size: 18),
                            label: const Text('Retake',
                                style: TextStyle(color: Colors.white70)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.white30),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(32)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: _handleContinue,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _limeGreen,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(32)),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('Continue to ID Upload',
                                style: TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _instruction(IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, color: Colors.white70, size: 16),
            const SizedBox(width: 8),
            Text(text, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ),
      );
}
