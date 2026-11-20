import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/dashboard_service.dart';
import 'dashboard_screen.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const Color _gold = Color(0xFFE8C547);
  static const Color _buttonColor = Color(0xFFE7CA55);
  static const Color _goldMuted = Color(0xFFA38B45);
  static const Color _hintColor = Color(0xFF6E6E6E);

  static const Color _errorColor = Color(0xFFFF6B6B);

  final TextEditingController _username = TextEditingController();
  final TextEditingController _password = TextEditingController();

  bool _obscurePassword = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final String username = _username.text.trim();
    final String password = _password.text;
    if (username.isEmpty || password.isEmpty) {
      setState(() => _error = 'Enter your username and password');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });

    DashboardSummary? summary;
    try {
      await AuthService.instance.login(username, password);
      summary = await DashboardService.instance.fetchSummary();
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
      return;
    }
    if (!mounted) return;
    setState(() => _loading = false);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => DashboardScreen(summary: summary)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;

    final double screenWidth = screenSize.width;
    final double screenHeight = screenSize.height;

    // Clamp width-based sizes so text stays readable on tablets in portrait.
    double sized(double fraction, double min, double max) =>
        (screenWidth * fraction).clamp(min, max);

    return Scaffold(
      body: Container(
        width: screenWidth,
        height: screenHeight,

        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/login_background.jpg'),
            fit: BoxFit.cover,
          ),
        ),

        child: SafeArea(
          child: Stack(
            children: [
              // ─────────────────────────
              // BRAND LOGO (top-left)
              // ─────────────────────────
              Positioned(
                top: sized(0.025, 16, 32),
                left: sized(0.02, 16, 32),
                child: Image.asset(
                  'assets/images/app_logo.png',
                  width: sized(0.25, 180, 260),
                  fit: BoxFit.contain,
                ),
              ),

              Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    sized(0.08, 80, 110),
                    16,
                    16,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ─────────────────────────
                      // TAGLINE
                      // ─────────────────────────
                      Text(
                        'Move Better with Confidence',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: sized(0.028, 22, 34),
                          fontWeight: FontWeight.w700,
                          color: _goldMuted,
                        ),
                      ),

                      SizedBox(height: screenHeight * 0.008),

                      Text(
                        'Recover Stronger with Every Step',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: sized(0.019, 16, 22),
                          fontWeight: FontWeight.w600,
                          color: _goldMuted,
                        ),
                      ),

                      SizedBox(height: screenHeight * 0.04),

                      _buildCard(sized, screenWidth),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(
    double Function(double, double, double) sized,
    double screenWidth,
  ) {
    // Card is taller than the sign_bg.png aspect ratio (495 x 586) for extra
    // breathing room; the Spacers below distribute the spacing.
    final double preferredWidth = (screenWidth * 0.27).clamp(320.0, 440.0);
    final double availableWidth = (screenWidth - 32).clamp(0.0, 440.0);
    final double cardWidth = preferredWidth < availableWidth
        ? preferredWidth
        : availableWidth;
    final double cardHeight = cardWidth * 1.3;

    return Container(
      width: cardWidth,
      height: cardHeight,

      padding: EdgeInsets.symmetric(horizontal: cardWidth * 0.1),

      // The asset already includes the card's fill, border and rounded corners.
      decoration: BoxDecoration(
        image: const DecorationImage(
          image: AssetImage('assets/images/sign_bg.png'),
          fit: BoxFit.fill,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 30,
            offset: Offset(0, 10),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(flex: 5),

          // ─────────────────────────
          // TITLE
          // ─────────────────────────
          Center(
            child: Text(
              'Sign In',
              style: TextStyle(
                fontSize: sized(0.022, 20, 26),
                fontWeight: FontWeight.w500,
                color: _gold,
              ),
            ),
          ),

          const Spacer(flex: 5),

          // ─────────────────────────
          // USER NAME
          // ─────────────────────────
          _label('User Name'),
          const SizedBox(height: 8),
          _field(
            controller: _username,
            hint: 'Enter your username',
            icon: Icons.person_outline,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),

          const Spacer(flex: 4),

          // ─────────────────────────
          // PASSWORD
          // ─────────────────────────
          _label('Password'),
          const SizedBox(height: 8),
          _field(
            controller: _password,
            hint: 'Enter your password',
            icon: Icons.key_outlined,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _signIn(),
            suffix: IconButton(
              splashRadius: 16,
              iconSize: 16,
              color: _hintColor,
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),

          const Spacer(flex: 2),

          // ─────────────────────────
          // ERROR MESSAGE
          // ─────────────────────────
          SizedBox(
            height: 18,
            child: _error == null
                ? null
                : Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 14,
                        color: _errorColor,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _error!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: _errorColor,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),

          const Spacer(flex: 3),

          // ─────────────────────────
          // SIGN IN BUTTON
          // ─────────────────────────
          SizedBox(
            width: double.infinity,
            height: 44,

            child: ElevatedButton(
              onPressed: _loading ? null : _signIn,

              style: ElevatedButton.styleFrom(
                backgroundColor: _buttonColor,
                foregroundColor: Colors.black,
                disabledBackgroundColor: _buttonColor.withValues(alpha: 0.6),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.black,
                      ),
                    )
                  : const Text(
                      'Sign In',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),

          const Spacer(flex: 7),
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: _gold,
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
    Widget? suffix,
  }) {
    // The text_box.png asset provides the field's fill, rounded corners and
    // gold bottom glow, so the TextField itself draws no background or border.
    return Container(
      height: 48,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/text_box.png'),
          fit: BoxFit.fill,
        ),
      ),
      child: TextField(
        controller: controller,
        onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        obscureText: obscureText,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        enabled: !_loading,
        // Clear a previous error as soon as the user edits a field.
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        cursorColor: _gold,
        style: const TextStyle(fontSize: 13, color: Colors.white),

        decoration: InputDecoration(
          isDense: true,
          filled: false,
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 12, color: _hintColor),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),

          // Icon inside a small dark circle, as in the design.
          prefixIcon: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: Color(0xFF2C2C2C),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 13, color: _goldMuted),
            ),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 38),
          suffixIcon: suffix,

          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }
}
