import 'package:flutter/material.dart';
import '../login_screen.dart';
import '../services/api_service.dart';

class VerificationWaitingScreen extends StatefulWidget {
  const VerificationWaitingScreen({super.key});

  @override
  State<VerificationWaitingScreen> createState() =>
      _VerificationWaitingScreenState();
}

class _VerificationWaitingScreenState
    extends State<VerificationWaitingScreen> {
  static const Color _green = Color(0xFF1A6B1A);
  static const Color _limeGreen = Color(0xFF4CFF4C);

  String? _status;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchStatus();
  }

  Future<void> _fetchStatus() async {
    try {
      // getMe() fetches fresh user data so accountStatus reflects what's in MongoDB
      final user = await ApiService.getMe() ?? await ApiService.getUser();
      if (mounted) {
        setState(() {
          _status = (user?['accountStatus'] as String?)?.toLowerCase();
          _loading = false;
        });
      }
    } catch (_) {
      // Fall back to cached user on network error
      final user = await ApiService.getUser();
      if (mounted) {
        setState(() {
          _status = (user?['accountStatus'] as String?)?.toLowerCase();
          _loading = false;
        });
      }
    }
  }

  static Widget _checkItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: Colors.green, size: 16),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F4),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _isUnderReview
                ? _buildUnderReviewBody(context)
                : _buildPendingBody(context),
      ),
    );
  }

  bool get _isUnderReview =>
      _status == 'under review' || _status == 'under_review';

  Widget _buildUnderReviewBody(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: Colors.blue.withValues(alpha: 0.2),
                      blurRadius: 20,
                      spreadRadius: 4)
                ],
              ),
              child: const Center(
                child: Icon(Icons.manage_search_rounded,
                    size: 52, color: Colors.blueAccent),
              ),
            ),
            const SizedBox(height: 28),

            const Text(
              'Your Account is Under Review',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.black87),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Sorry for inconvenience. Our team is carefully reviewing your account. We appreciate your patience.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.black54, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 28),

            // Status box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                children: [
                  const Text('Current Status',
                      style: TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Under Review',
                      style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 22,
                          fontWeight: FontWeight.w900)),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Back to home
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: () async {
                  await ApiService.clearSession();
                  if (!context.mounted) return;
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const LoginScreen()),
                    (_) => false,
                  );
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _green),
                  foregroundColor: _green,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(32)),
                ),
                child: const Text('Back to Home',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              "You'll receive SMS notification when your status changes.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black45, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingBody(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Hourglass icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF9C4),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: Colors.orange.withValues(alpha: 0.2),
                      blurRadius: 20,
                      spreadRadius: 4)
                ],
              ),
              child: const Center(
                child: Text('⏳', style: TextStyle(fontSize: 48)),
              ),
            ),
            const SizedBox(height: 28),

            const Text(
              'Verification in Progress',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.black87),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Your documents have been submitted. Please wait while we review your information.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.black54, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 24),

            // Expected time box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                children: [
                  const Text('Expected Time',
                      style: TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('2 - 6 Hours',
                      style: TextStyle(
                          color: Colors.orange.shade700,
                          fontSize: 22,
                          fontWeight: FontWeight.w900)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Submitted checklist
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Submitted Information',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.black87)),
                  const SizedBox(height: 12),
                  _submittedItem('Demographic Profile'),
                  _submittedItem('Educational Attainment'),
                  _submittedItem('ID Documents'),
                  _submittedItem('Face Recognition'),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Back to home
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: () async {
                  await ApiService.clearSession();
                  if (!context.mounted) return;
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const LoginScreen()),
                    (_) => false,
                  );
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _green),
                  foregroundColor: _green,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(32)),
                ),
                child: const Text('Back to Home',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 20),

            // Info banner
            const Text(
              "You'll receive SMS notification when approved.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black45, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _submittedItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: _green, size: 18),
          const SizedBox(width: 10),
          Text(text,
              style: const TextStyle(fontSize: 13, color: Colors.black87)),
        ],
      ),
    );
  }
}
