import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/api_service.dart';
import 'reset_password_screen.dart';
import 'verification/demographic_screen.dart';

class OtpScreen extends StatefulWidget {
  final String userId;
  final String type; // 'register' or 'reset'
  final String maskedContact; // e.g. "09*****123"

  const OtpScreen({
    super.key,
    required this.userId,
    required this.type,
    required this.maskedContact,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  static const Color _green = Color(0xFF1A6B1A);
  static const Color _gold = Color(0xFFFFD700);
  static const Color _limeGreen = Color(0xFF4CFF4C);

  static const int _otpLength = 6;
  static const int _resendCooldown = 60; // seconds

  final List<TextEditingController> _controllers =
      List.generate(_otpLength, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(_otpLength, (_) => FocusNode());

  bool _isVerifying = false;
  bool _isResending = false;
  int _secondsLeft = _resendCooldown;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = _resendCooldown);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  String get _otpCode => _controllers.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    if (value.length == 1 && index < _otpLength - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    // Auto-submit when all filled
    if (_otpCode.length == _otpLength) {
      _handleVerify();
    }
  }

  void _onKeyEvent(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _handleVerify() async {
    if (_otpCode.length < _otpLength || _isVerifying) return;

    setState(() => _isVerifying = true);
    try {
      final result = await ApiService.verifyOtp(
        userId: widget.userId,
        code: _otpCode,
        type: widget.type,
      );

      if (!mounted) return;

      if (result['statusCode'] == 200) {
        if (widget.type == 'register') {
          // New account — always go to demographic profile first
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const DemographicScreen()),
            (_) => false,
          );
        } else {
          // Reset flow — go to reset password screen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ResetPasswordScreen(
                resetToken: result['resetToken'] as String,
              ),
            ),
          );
        }
      } else {
        _showError(result['message'] as String? ?? 'Invalid OTP');
        _clearOtp();
      }
    } catch (_) {
      if (mounted) _showError('Connection error. Please try again.');
      _clearOtp();
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _handleResend() async {
    if (_secondsLeft > 0 || _isResending) return;

    setState(() => _isResending = true);
    try {
      await ApiService.resendOtp(userId: widget.userId, type: widget.type);
      if (!mounted) return;
      _clearOtp();
      _startTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('OTP resent successfully'),
          backgroundColor: Color(0xFF1A6B1A),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (mounted) _showError('Failed to resend OTP. Try again.');
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _clearOtp() {
    for (final c in _controllers) c.clear();
    _focusNodes[0].requestFocus();
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
    final title = widget.type == 'register' ? 'Verify Account' : 'Reset Password';
    final subtitle =
        'Enter the 6-digit OTP sent to\n${widget.maskedContact}';

    return Scaffold(
      backgroundColor: _green,
      appBar: AppBar(
        backgroundColor: _green,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(title, style: const TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline_rounded, color: _gold, size: 64),
              const SizedBox(height: 20),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 40),

              // OTP boxes
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(_otpLength, (i) => _buildBox(i)),
              ),
              const SizedBox(height: 40),

              // Verify button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isVerifying ? null : _handleVerify,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _limeGreen,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(32),
                    ),
                    elevation: 0,
                  ),
                  child: _isVerifying
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.black54,
                          ),
                        )
                      : const Text(
                          'Verify',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
              const SizedBox(height: 24),

              // Resend
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Didn't receive the code? ",
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  _secondsLeft > 0
                      ? Text(
                          'Resend in ${_secondsLeft}s',
                          style: const TextStyle(color: Colors.white54, fontSize: 14),
                        )
                      : GestureDetector(
                          onTap: _isResending ? null : _handleResend,
                          child: Text(
                            _isResending ? 'Sending...' : 'Resend',
                            style: const TextStyle(
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBox(int index) {
    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: (e) => _onKeyEvent(index, e),
      child: SizedBox(
        width: 46,
        height: 56,
        child: TextField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: 1,
          onChanged: (v) => _onDigitChanged(index, v),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: _green,
          ),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _gold, width: 2),
            ),
          ),
        ),
      ),
    );
  }
}
