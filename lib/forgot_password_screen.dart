import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'otp_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  static const Color _green = Color(0xFF1A6B1A);
  static const Color _gold = Color(0xFFFFD700);
  static const Color _limeGreen = Color(0xFF4CFF4C);

  final _usernameController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      _showError('Please enter your username');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final result = await ApiService.forgotPassword(username: username);

      if (!mounted) return;

      // Always show success message (server doesn't reveal if user exists)
      if (result['statusCode'] == 200) {
        final userId = result['userId'] as String?;
        if (userId == null) {
          // Username not found — server returned generic message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('If that username exists, an OTP has been sent.'),
              backgroundColor: Color(0xFF1A6B1A),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpScreen(
              userId: userId,
              type: 'reset',
              maskedContact: _maskUsername(username),
            ),
          ),
        );
      } else {
        _showError(result['message'] as String? ?? 'Something went wrong');
      }
    } catch (_) {
      if (mounted) _showError('Connection error. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _maskUsername(String username) {
    if (username.length <= 3) return username;
    return '${username[0]}${'*' * (username.length - 2)}${username[username.length - 1]}';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
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
        title: const Text('Forgot Password', style: TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lock_reset_rounded, color: _gold, size: 64),
              const SizedBox(height: 20),
              const Text(
                'Reset Password',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter your username and we\'ll send an OTP to your registered contact number.',
                style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 36),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                ),
                child: TextField(
                  controller: _usernameController,
                  style: const TextStyle(
                    color: _green,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Username',
                    hintStyle: TextStyle(
                      color: _green,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _limeGreen,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(32),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.black54,
                          ),
                        )
                      : const Text(
                          'Send OTP',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
