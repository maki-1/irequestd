import 'package:flutter/material.dart';
import '../login_screen.dart';
import '../services/api_service.dart';

class VerificationWaitingScreen extends StatelessWidget {
  const VerificationWaitingScreen({super.key});

  static const Color _green = Color(0xFF1A6B1A);
  static const Color _limeGreen = Color(0xFF4CFF4C);

  void _showStatusDialog(BuildContext context) async {
    final result = await ApiService.getVerificationStatus();
    if (!context.mounted) return;

    final submittedAt = result['submittedAt'] as String?;
    String dateStr = 'Unknown';
    if (submittedAt != null) {
      final dt = DateTime.tryParse(submittedAt);
      if (dt != null) {
        const months = [
          'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
        ];
        dateStr =
            '${months[dt.month - 1]} ${dt.day}, ${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Submission Details',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow('Status', result['status'] ?? 'Pending', Colors.orange),
            const SizedBox(height: 8),
            _detailRow('Submitted', dateStr, Colors.black54),
            const SizedBox(height: 16),
            const Text('Submitted Items:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 6),
            _checkItem('Demographic Profile'),
            _checkItem('Educational Attainment'),
            _checkItem('ID Documents'),
            _checkItem('Face Recognition'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: _green)),
          ),
        ],
      ),
    );
  }

  static Widget _detailRow(String label, String value, Color valueColor) {
    return Row(
      children: [
        Text('$label: ',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        Text(value, style: TextStyle(color: valueColor, fontSize: 13)),
      ],
    );
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
        child: Center(
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
                  'Your documents have been submitted to our secretary for verification.',
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
                      Text('24 - 72 Hours',
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

                // Check status
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => _showStatusDialog(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(32)),
                      elevation: 0,
                    ),
                    child: const Text('Check Status',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 12),

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
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
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
