import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late final AnimationController _ctrl;

  late final Animation<double> _myFade;
  late final Animation<double> _mySlide;
  late final Animation<double> _abaFade;
  late final Animation<double> _abaSlide;
  late final Animation<double> _RFade;
  late final Animation<double> _RBounce;
  late final Animation<double> _subFade;
  late final Animation<double> _cardFade;
  late final Animation<double> _btnFade;
  late final Animation<double> _bgFade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4500),
    );

    _bgFade = CurvedAnimation(
        parent: _ctrl, curve: const Interval(0.00, 0.18, curve: Curves.easeIn));

    _myFade = CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.08, 0.26, curve: Curves.easeOut));
    _mySlide = Tween<double>(begin: -40, end: 0).animate(CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.08, 0.26, curve: Curves.easeOut)));

    _abaFade = CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.32, 0.50, curve: Curves.easeOut));
    _abaSlide = Tween<double>(begin: 40, end: 0).animate(CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.32, 0.50, curve: Curves.easeOut)));

    _RFade = CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.20, 0.36, curve: Curves.easeOut));
    _RBounce = Tween<double>(begin: -80, end: 0).animate(CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.20, 0.48, curve: Curves.elasticOut)));

    _subFade = CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.54, 0.68, curve: Curves.easeOut));
    _cardFade = CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.63, 0.76, curve: Curves.easeOut));
    _btnFade = CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.74, 0.88, curve: Curves.easeOut));

    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0818),
      body: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => Stack(
          fit: StackFit.expand,
          children: [
            // ── Deep purple gradient background ───────────────────
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF1A0535),
                    Color(0xFF0C0818),
                    Color(0xFF160420),
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),

            // ── Soft centre glow (replaces unicorn) ──────────────
            Positioned.fill(
              child: Opacity(
                opacity: _bgFade.value * 0.6,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 0.9,
                      colors: [
                        const Color(0xFF9333EA).withValues(alpha: 0.18),
                        const Color(0xFFFF6B00).withValues(alpha: 0.08),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),
            ),

            // ── Orange warm glow at bottom ────────────────────────
            Positioned.fill(
              child: Opacity(
                opacity: _bgFade.value * 0.7,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, 1.2),
                      radius: 0.8,
                      colors: [
                        const Color(0xFFFF6B00).withValues(alpha: 0.45),
                        const Color(0xFF9333EA).withValues(alpha: 0.15),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),
            ),

            // ── Top purple glow ───────────────────────────────────
            Positioned.fill(
              child: Opacity(
                opacity: _bgFade.value * 0.5,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.8),
                      radius: 0.6,
                      colors: [
                        const Color(0xFF9333EA).withValues(alpha: 0.3),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Main content ─────────────────────────────────────
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    const Spacer(flex: 2),

                    _buildWordmark(),

                    const SizedBox(height: 18),

                    Opacity(
                      opacity: _subFade.value,
                      child: const Text(
                        'Send money, save together,\ngive with meaning.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.6,
                          color: Colors.white70,
                        ),
                      ),
                    ),

                    const Spacer(flex: 3),

                    // Feature strip
                    Opacity(
                      opacity: _cardFade.value,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 22, horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.10)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _feature(Icons.send_rounded, 'Send'),
                            _featureDivider(),
                            _feature(Icons.savings_rounded, 'Save'),
                            _featureDivider(),
                            _feature(Icons.card_giftcard_rounded, 'Gift'),
                            _featureDivider(),
                            _feature(Icons.receipt_long_rounded, 'Bills'),
                          ],
                        ),
                      ),
                    ),

                    const Spacer(flex: 2),

                    // Buttons
                    Opacity(
                      opacity: _btnFade.value,
                      child: Column(children: [
                        // Create Account — solid orange gradient pill
                        GestureDetector(
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const RegisterScreen())),
                          child: Container(
                            width: double.infinity,
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF8C00), Color(0xFFE85D00)],
                              ),
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF6B00)
                                      .withValues(alpha: 0.4),
                                  blurRadius: 20,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              'Create Account',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Log In — outlined orange pill
                        GestureDetector(
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const LoginScreen())),
                          child: Container(
                            width: double.infinity,
                            height: 56,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                  color: const Color(0xFFFF8C00), width: 1.5),
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              'Log In',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFFF8C00),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),
                        const Text(
                          'By continuing you agree to our Terms of Service\nand Privacy Policy.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 11, color: Colors.white38, height: 1.6),
                        ),
                        const SizedBox(height: 20),
                      ]),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWordmark() {
    const style = TextStyle(
      fontSize: 58,
      fontWeight: FontWeight.w900,
      letterSpacing: 1,
      color: Colors.white,
    );

    return SizedBox(
      height: 76,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // "My" — orange
          Opacity(
            opacity: _myFade.value,
            child: Transform.translate(
              offset: Offset(_mySlide.value, 0),
              child: ShaderMask(
                shaderCallback: (b) => const LinearGradient(
                  colors: [Color(0xFFFF8C00), Color(0xFFFF6B00)],
                ).createShader(b),
                blendMode: BlendMode.srcIn,
                child: const Text('My', style: style),
              ),
            ),
          ),

          // "R" — gold shimmer, bounces from above
          Opacity(
            opacity: _RFade.value,
            child: Transform.translate(
              offset: Offset(0, _RBounce.value),
              child: ShaderMask(
                shaderCallback: (b) => const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFFA500), Color(0xFFFFD700)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ).createShader(b),
                blendMode: BlendMode.srcIn,
                child: const Text('R', style: style),
              ),
            ),
          ),

          // "aba" — orange
          Opacity(
            opacity: _abaFade.value,
            child: Transform.translate(
              offset: Offset(_abaSlide.value, 0),
              child: ShaderMask(
                shaderCallback: (b) => const LinearGradient(
                  colors: [Color(0xFFFF6B00), Color(0xFFFF8C00)],
                ).createShader(b),
                blendMode: BlendMode.srcIn,
                child: const Text('aba', style: style),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _feature(IconData icon, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF8C00), Color(0xFFE85D00)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(height: 8),
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                color: Colors.white70,
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _featureDivider() => Container(
      width: 1, height: 44, color: Colors.white.withValues(alpha: 0.12));
}
