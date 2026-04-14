import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'signup_screen.dart';
import 'otp_screen.dart';
import 'forgot_password_screen.dart';
import 'services/api_service.dart';
import 'verification/demographic_screen.dart';
import 'verification/education_screen.dart';
import 'verification/face_recognition_screen.dart';
import 'verification/verification_waiting_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const Color _green = Color(0xFF1A6B1A);
  static const Color _gold = Color(0xFFFFD700);
  static const Color _limeGreen = Color(0xFF4CFF4C);

  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      _showError('Please enter your username and password');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final result = await ApiService.login(
        username: username,
        password: password,
      );

      if (!mounted) return;

      if (result['statusCode'] == 200) {
        final user = result['user'] as Map<String, dynamic>?;
        final vStatus = user?['accountStatus'] as String?;
        final vStep = user?['verificationStep'] as int? ?? 1;
        _routeAfterLogin(vStatus, vStep);
      } else if (result['statusCode'] == 403 &&
          result['requiresVerification'] == true) {
        // Account exists but OTP not verified — go to OTP screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpScreen(
              userId: result['userId'] as String,
              type: 'register',
              maskedContact: 'your registered number',
            ),
          ),
        );
      } else {
        _showError(result['message'] as String? ?? 'Login failed');
      }
    } catch (_) {
      if (mounted) _showError('Could not connect to server. Check your connection.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _routeAfterLogin(String? verificationStatus, int step) {
    Widget destination;
    if (verificationStatus == 'approved') {
      destination = const DashboardScreen();
    } else if (verificationStatus == 'pending') {
      destination = const VerificationWaitingScreen();
    } else if (verificationStatus == 'draft' || verificationStatus == null) {
      // Route to whichever step they left off at
      if (step >= 3) {
        destination = const FaceRecognitionScreen();
      } else if (step >= 2) {
        destination = const EducationScreen();
      } else {
        destination = const DemographicScreen();
      }
    } else {
      // 'rejected' — start over
      destination = const DemographicScreen();
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => destination),
    );
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

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    bool obscure = false,
    VoidCallback? onToggle,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: const TextStyle(
          color: _green,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            color: _green,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          border: InputBorder.none,
          suffixIcon: onToggle != null
              ? IconButton(
                  icon: Icon(
                    obscure ? Icons.visibility_off : Icons.visibility,
                    color: _green,
                  ),
                  onPressed: onToggle,
                )
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _green,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 48),
              // App logo
              Center(
                child: Image.network(
                  'https://res.cloudinary.com/dvw7ky1xq/image/upload/v1776177600/Irequest_Logo_kbbr2b.jpg',
                  width: 160,
                  height: 160,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'WELCOME BACK!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Don't have an account? ",
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const SignUpScreen()),
                    ),
                    child: const Text(
                      'Sign Up',
                      style: TextStyle(
                        color: _gold,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                        decorationColor: _gold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 36),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    _buildField(
                      controller: _usernameController,
                      hint: 'Username',
                    ),
                    const SizedBox(height: 16),
                    _buildField(
                      controller: _passwordController,
                      hint: 'Enter Password',
                      obscure: _obscurePassword,
                      onToggle: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
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
                                'Login',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ForgotPasswordScreen(),
                        ),
                      ),
                      child: const Text(
                        'Forgot your password?',
                        style: TextStyle(
                          color: _gold,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                          decorationColor: _gold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
