import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'signup_screen.dart';
import 'dashboard_screen.dart';
import 'settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final seenOnboarding = prefs.getBool('seen_onboarding') ?? false;
  runApp(MyApp(showOnboarding: !seenOnboarding));
}

class MyApp extends StatelessWidget {
  final bool showOnboarding;
  const MyApp({super.key, required this.showOnboarding});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'iRequest Dologon',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A6B1A)),
      ),
      home: showOnboarding ? const OnboardingScreen() : const LoginScreen(),
      routes: {
        '/dashboard': (_) => const DashboardScreen(),
        '/settings': (_) => const SettingsScreen(),
      },
    );
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const Color _green = Color(0xFF1A6B1A);
  static const Color _gold = Color(0xFFFFD700);

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildSkipButton({required bool onGreenBg}) {
    return TextButton(
      onPressed: _skipToLast,
      style: TextButton.styleFrom(
        foregroundColor: onGreenBg ? Colors.white70 : Colors.black45,
      ),
      child: const Text(
        'Skip',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildDots({required bool onGreenBg}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        final isActive = index == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 12 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive
                ? (onGreenBg ? Colors.white : _green)
                : (onGreenBg
                    ? Colors.white.withValues(alpha: 0.4)
                    : Colors.grey.shade400),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  Widget _titleiRequest({bool onGreenBg = true}) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: 'iRequest',
            style: TextStyle(
              fontStyle: FontStyle.italic,
              color: onGreenBg ? _gold : Colors.black87,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(
            text: 'Dologon',
            style: TextStyle(
              color: onGreenBg ? Colors.white : Colors.black,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _titleIRequest() {
    return RichText(
      text: const TextSpan(
        children: [
          TextSpan(
            text: 'I-Request ',
            style: TextStyle(
              color: _gold,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(
            text: 'Dologon',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlide1() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_green, Colors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.45, 0.75],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 50),
            _titleiRequest(onGreenBg: true),
            const Spacer(),
            Image.network(
              'https://res.cloudinary.com/dvw7ky1xq/image/upload/irequestd/assets/page1.png',
              width: 360,
              height: 340,
              fit: BoxFit.contain,
            ),
            const Spacer(),
            const Text(
              '"Your requests, made simple."',
              style: TextStyle(
                color: Color(0xFF333333),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            _buildDots(onGreenBg: false),
            _buildSkipButton(onGreenBg: false),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSlide2() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white, _green],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.4, 0.85],
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.only(top: 32),
              child: Center(
                child: RichText(
                  text: const TextSpan(
                    children: [
                      TextSpan(
                        text: 'iRequest',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: _gold,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextSpan(
                        text: 'Dologon',
                        style: TextStyle(
                          color: _green,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          bottom: 0,
          left: 0,
          right: 0,
          child: Center(
            child: Image.network(
              'https://res.cloudinary.com/dvw7ky1xq/image/upload/irequestd/assets/page2.png',
              width: 360,
              height: 340,
              fit: BoxFit.contain,
            ),
          ),
        ),
        Positioned(
          left: 24,
          right: 24,
          bottom: 40,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '"Track your requests in real-time"',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),
              _buildDots(onGreenBg: true),
              _buildSkipButton(onGreenBg: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSlide3() {
    return Container(
      color: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 50),
            RichText(
              text: const TextSpan(
                children: [
                  TextSpan(
                    text: 'I-Request ',
                    style: TextStyle(
                      color: _gold,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(
                    text: 'Dologon',
                    style: TextStyle(
                      color: _green,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Image.network(
                  'https://res.cloudinary.com/dvw7ky1xq/image/upload/irequestd/assets/docu.gif',
                  width: 340,
                  height: 320,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const Text(
              'Real Time Update',
              style: TextStyle(
                color: _green,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            _buildDots(onGreenBg: false),
            _buildSkipButton(onGreenBg: false),
          ],
        ),
      ),
    );
  }

  Future<void> _goToLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seen_onboarding', true);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Widget _buildSlide4() {
    return Container(
      color: _green,
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _titleIRequest(),
            const SizedBox(height: 30),
            Image.network(
              'https://res.cloudinary.com/dvw7ky1xq/image/upload/irequestd/assets/image.png',
              width: 260,
              height: 240,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 30),
            const Text(
              '"Let\'s Get Started"',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 24),
            // Login button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _goToLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Login',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            // Sign up link
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Don't have an account? ",
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                GestureDetector(
                  onTap: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('seen_onboarding', true);
                    if (!mounted) return;
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const SignUpScreen()),
                    );
                  },
                  child: const Text(
                    'Sign Up',
                    style: TextStyle(
                      color: _gold,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                      decorationColor: _gold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            _buildDots(onGreenBg: true),
          ],
        ),
      ),
    );
  }

  void _skipToLast() {
    _pageController.animateToPage(
      3,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  bool get mounted => context.mounted;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        key: const ValueKey('onboarding_pageview'),
        controller: _pageController,
        onPageChanged: (index) => setState(() => _currentPage = index),
        children: [
          _buildSlide1(),
          _buildSlide2(),
          _buildSlide3(),
          _buildSlide4(),
        ],
      ),
    );
  }
}
