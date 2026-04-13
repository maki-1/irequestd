import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'login_screen.dart';
import 'otp_screen.dart';
import 'services/api_service.dart';

// ── Phone number auto-formatter ───────────────────────────────────────────────
class _PhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    String digits = newValue.text.replaceAll(RegExp(r'\D'), '');

    // Strip leading country code if typed
    if (digits.startsWith('63')) digits = '0${digits.substring(2)}';
    if (digits.length > 11) digits = digits.substring(0, 11);

    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i == 4 || i == 7) buffer.write(' ');
      buffer.write(digits[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  static const Color _green = Color(0xFF1A6B1A);
  static const Color _gold = Color(0xFFFFD700);
  static const Color _limeGreen = Color(0xFF4CFF4C);

  final _usernameController = TextEditingController();
  final _contactController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  // Username availability
  String _usernameStatus = ''; // '', 'checking', 'available', 'taken', 'invalid'
  Timer? _usernameDebounce;

  // Contact availability
  String _contactStatus = ''; // '', 'checking', 'available', 'taken', 'invalid'
  Timer? _contactDebounce;

  // Email availability
  String _emailStatus = ''; // '', 'checking', 'available', 'taken', 'invalid'
  Timer? _emailDebounce;

  // Password strength (0–5 requirements met)
  int _passwordStrength = 0;
  bool _passwordTouched = false;

  // Confirm password
  bool _passwordsMatch = false;
  bool _confirmTouched = false;

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(_onUsernameChanged);
    _contactController.addListener(_onContactChanged);
    _emailController.addListener(_onEmailChanged);
    _passwordController.addListener(_onPasswordChanged);
    _confirmPasswordController.addListener(_onConfirmChanged);
  }

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    _contactDebounce?.cancel();
    _emailDebounce?.cancel();
    _usernameController.dispose();
    _contactController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ── Validators ──────────────────────────────────────────────────────────────

  bool _isValidUsernameFormat(String v) =>
      RegExp(r'^[a-zA-Z0-9_]{6,20}$').hasMatch(v);

  bool _isValidEmail(String v) =>
      RegExp(r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$')
          .hasMatch(v);

  bool _isValidPhilippineNumber(String v) {
    final digits = v.replaceAll(RegExp(r'\D'), '');
    return RegExp(r'^09\d{9}$').hasMatch(digits);
  }

  int _calcStrength(String password) {
    int score = 0;
    if (password.length >= 8) score++;
    if (password.contains(RegExp(r'[A-Z]'))) score++;
    if (password.contains(RegExp(r'[a-z]'))) score++;
    if (password.contains(RegExp(r'[0-9]'))) score++;
    if (password.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-+=\[\]\\;/]')))
      score++;
    return score;
  }

  // ── Listeners ───────────────────────────────────────────────────────────────

  void _onUsernameChanged() {
    final value = _usernameController.text;
    _usernameDebounce?.cancel();

    if (value.isEmpty) {
      setState(() => _usernameStatus = '');
      return;
    }
    if (!_isValidUsernameFormat(value)) {
      setState(() => _usernameStatus = 'invalid');
      return;
    }

    setState(() => _usernameStatus = 'checking');
    _usernameDebounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final available = await ApiService.checkUsernameAvailable(value);
        if (!mounted) return;
        // Only update if the input hasn't changed
        if (_usernameController.text == value) {
          setState(() => _usernameStatus = available ? 'available' : 'taken');
        }
      } catch (_) {
        if (mounted) setState(() => _usernameStatus = '');
      }
    });
  }

  void _onContactChanged() {
    final value = _contactController.text;
    _contactDebounce?.cancel();

    if (value.isEmpty) {
      setState(() => _contactStatus = '');
      return;
    }
    if (!_isValidPhilippineNumber(value)) {
      setState(() => _contactStatus = 'invalid');
      return;
    }

    setState(() => _contactStatus = 'checking');
    _contactDebounce = Timer(const Duration(milliseconds: 600), () async {
      try {
        final available = await ApiService.checkContactAvailable(value);
        if (!mounted) return;
        if (_contactController.text == value) {
          setState(() => _contactStatus = available ? 'available' : 'taken');
        }
      } catch (_) {
        if (mounted) setState(() => _contactStatus = 'available');
      }
    });
  }

  void _onEmailChanged() {
    final value = _emailController.text.trim();
    _emailDebounce?.cancel();

    if (value.isEmpty) {
      setState(() => _emailStatus = '');
      return;
    }
    if (!_isValidEmail(value)) {
      setState(() => _emailStatus = 'invalid');
      return;
    }

    setState(() => _emailStatus = 'checking');
    _emailDebounce = Timer(const Duration(milliseconds: 600), () async {
      try {
        final available = await ApiService.checkEmailAvailable(value);
        if (!mounted) return;
        if (_emailController.text.trim() == value) {
          setState(() => _emailStatus = available ? 'available' : 'taken');
        }
      } catch (_) {
        if (mounted) setState(() => _emailStatus = 'available');
      }
    });
  }

  void _onPasswordChanged() {
    setState(() {
      _passwordTouched = true;
      _passwordStrength = _calcStrength(_passwordController.text);
      if (_confirmTouched) {
        _passwordsMatch =
            _passwordController.text == _confirmPasswordController.text;
      }
    });
  }

  void _onConfirmChanged() {
    setState(() {
      _confirmTouched = true;
      _passwordsMatch =
          _passwordController.text == _confirmPasswordController.text &&
              _passwordController.text.isNotEmpty;
    });
  }

  // ── Submit gate ─────────────────────────────────────────────────────────────

  bool get _canSubmit {
    final emailOk = _emailController.text.trim().isEmpty ||
        _emailStatus == 'available';
    return _usernameStatus == 'available' &&
        _contactStatus == 'available' &&
        emailOk &&
        _passwordStrength >= 4 &&
        _passwordsMatch &&
        !_isLoading;
  }

  // ── Register ─────────────────────────────────────────────────────────────────

  Future<void> _handleRegister() async {
    if (!_canSubmit) return;

    final username = _usernameController.text.trim();
    final contact =
        _contactController.text.replaceAll(RegExp(r'\D'), '');
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    setState(() => _isLoading = true);
    try {
      final result = await ApiService.register(
        username: username,
        contactNumber: contact,
        email: email,
        password: password,
        confirmPassword: confirm,
      );

      if (!mounted) return;

      if (result['statusCode'] == 201) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => OtpScreen(
              userId: result['userId'] as String,
              type: 'register',
              maskedContact: _maskContact(contact),
            ),
          ),
        );
      } else {
        _showError(result['message'] as String? ?? 'Registration failed');
      }
    } catch (_) {
      if (mounted) _showError('Could not connect to server. Check your connection.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _maskContact(String digits) {
    if (digits.length < 4) return digits;
    return '${digits.substring(0, 2)}${'*' * (digits.length - 4)}${digits.substring(digits.length - 2)}';
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

  // ── UI helpers ───────────────────────────────────────────────────────────────

  Widget _buildLabel(String text) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 6),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    bool obscure = false,
    VoidCallback? onToggle,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? formatters,
    Widget? suffixIcon,
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
        inputFormatters: formatters,
        style: const TextStyle(
          color: _green,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            color: Color(0xFF7BAE7B),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          border: InputBorder.none,
          suffixIcon: onToggle != null
              ? IconButton(
                  icon: Icon(
                    obscure ? Icons.visibility_off : Icons.visibility,
                    color: _green,
                  ),
                  onPressed: onToggle,
                )
              : suffixIcon,
        ),
      ),
    );
  }

  Widget _buildHint(String text, {Color color = Colors.white54}) => Padding(
        padding: const EdgeInsets.only(left: 12, top: 4),
        child: Text(text, style: TextStyle(fontSize: 12, color: color)),
      );

  Widget _buildStatusHint(String status,
      {String? invalidMsg, String takenMsg = 'Already registered ✗'}) {
    switch (status) {
      case 'checking':
        return _buildHint('Checking...');
      case 'available':
        return _buildHint('Available ✓', color: _limeGreen);
      case 'taken':
        return _buildHint(takenMsg, color: Colors.redAccent);
      case 'invalid':
        return _buildHint(invalidMsg ?? 'Invalid format', color: Colors.orangeAccent);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStatusIcon(String status) {
    switch (status) {
      case 'checking':
        return const Padding(
          padding: EdgeInsets.all(12),
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1A6B1A)),
          ),
        );
      case 'available':
        return const Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32));
      case 'taken':
        return const Icon(Icons.cancel_rounded, color: Colors.redAccent);
      case 'invalid':
        return const Icon(Icons.error_outline_rounded, color: Colors.orangeAccent);
      default:
        return const SizedBox.shrink();
    }
  }

  // Password strength bar
  Widget _buildStrengthBar() {
    if (!_passwordTouched || _passwordController.text.isEmpty) {
      return const SizedBox.shrink();
    }

    final strength = _passwordStrength;
    final int filled = strength <= 1
        ? 1
        : strength == 2
            ? 2
            : strength == 3
                ? 3
                : 4;
    final Color barColor = strength <= 2
        ? Colors.redAccent
        : strength == 3
            ? Colors.orange
            : Colors.green;
    final String label = strength <= 2
        ? 'Weak'
        : strength == 3
            ? 'Medium'
            : 'Strong';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: List.generate(4, (i) {
            return Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                height: 5,
                decoration: BoxDecoration(
                  color: i < filled ? barColor : Colors.white24,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: barColor, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 6),
        _buildRequirement('At least 8 characters', _passwordController.text.length >= 8),
        _buildRequirement('Uppercase letter (A-Z)',
            _passwordController.text.contains(RegExp(r'[A-Z]'))),
        _buildRequirement('Lowercase letter (a-z)',
            _passwordController.text.contains(RegExp(r'[a-z]'))),
        _buildRequirement(
            'Number (0-9)', _passwordController.text.contains(RegExp(r'[0-9]'))),
        _buildRequirement('Special character (recommended)',
            _passwordController.text
                .contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-+=\[\]\\;/]')),
            recommended: true),
      ],
    );
  }

  Widget _buildRequirement(String text, bool met, {bool recommended = false}) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 2),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 14,
            color: met
                ? Colors.greenAccent
                : recommended
                    ? Colors.white38
                    : Colors.white54,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: met
                  ? Colors.greenAccent
                  : recommended
                      ? Colors.white38
                      : Colors.white60,
            ),
          ),
        ],
      ),
    );
  }

  // Confirm password match indicator
  Widget _buildConfirmStatus() {
    if (!_confirmTouched || _confirmPasswordController.text.isEmpty) {
      return const SizedBox.shrink();
    }
    return _passwordsMatch
        ? _buildHint('Passwords match ✓', color: _limeGreen)
        : _buildHint('Passwords do not match ✗', color: Colors.redAccent);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _green,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),
              const Text(
                'SIGN UP',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Text(
                    'Already have an account? ',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    ),
                    child: const Text(
                      'Sign in',
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
              const SizedBox(height: 32),

              // ── Username ─────────────────────────────────────────────────────
              _buildLabel('Username *'),
              _buildField(
                controller: _usernameController,
                hint: '6–20 characters',
                suffixIcon: _buildStatusIcon(_usernameStatus),
                formatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
                  LengthLimitingTextInputFormatter(20),
                ],
              ),
              _buildStatusHint(
                _usernameStatus,
                invalidMsg: '6–20 characters, letters, numbers and underscore only',
                takenMsg: 'Username taken ✗',
              ),
              const SizedBox(height: 16),

              // ── Contact Number ────────────────────────────────────────────────
              _buildLabel('Contact Number *'),
              _buildField(
                controller: _contactController,
                hint: '09XX XXXX XXX',
                keyboardType: TextInputType.phone,
                formatters: [_PhoneFormatter()],
                suffixIcon: _buildStatusIcon(_contactStatus),
              ),
              _buildStatusHint(
                _contactStatus,
                invalidMsg: 'Enter a valid PH number (09XXXXXXXXX)',
                takenMsg: 'Contact number already registered ✗',
              ),
              const SizedBox(height: 16),

              // ── Email (optional) ──────────────────────────────────────────────
              _buildLabel('Email (Optional)'),
              _buildField(
                controller: _emailController,
                hint: 'your@email.com',
                keyboardType: TextInputType.emailAddress,
                suffixIcon: _emailStatus.isEmpty ? null : _buildStatusIcon(_emailStatus),
              ),
              _buildStatusHint(
                _emailStatus,
                invalidMsg: 'Enter a valid email address',
                takenMsg: 'Email already registered ✗',
              ),
              const SizedBox(height: 16),

              // ── Password ──────────────────────────────────────────────────────
              _buildLabel('Password *'),
              _buildField(
                controller: _passwordController,
                hint: 'Min 8 characters',
                obscure: _obscurePassword,
                onToggle: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
              _buildStrengthBar(),
              const SizedBox(height: 16),

              // ── Confirm Password ──────────────────────────────────────────────
              _buildLabel('Confirm Password *'),
              _buildField(
                controller: _confirmPasswordController,
                hint: 'Repeat password',
                obscure: _obscureConfirm,
                onToggle: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
                suffixIcon: _confirmTouched &&
                        _confirmPasswordController.text.isNotEmpty
                    ? Icon(
                        _passwordsMatch
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded,
                        color:
                            _passwordsMatch ? Colors.green : Colors.redAccent,
                      )
                    : null,
              ),
              _buildConfirmStatus(),
              const SizedBox(height: 36),

              // ── Register button ───────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _canSubmit ? _handleRegister : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _canSubmit ? _limeGreen : Colors.white24,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: Colors.white24,
                    disabledForegroundColor: Colors.white38,
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
                          'Register',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
