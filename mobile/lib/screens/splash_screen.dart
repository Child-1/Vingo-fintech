import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'welcome_screen.dart';
import 'main_screen.dart';
import 'admin_dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {

  late final AnimationController _mainCtrl;
  late final AnimationController _shimmerCtrl;

  late final Animation<double> _myFade;
  late final Animation<double> _mySlide;
  late final Animation<double> _abaFade;
  late final Animation<double> _abaSlide;
  late final Animation<double> _RFade;
  late final Animation<double> _RBounce;
  late final Animation<double> _tagFade;
  late final Animation<double> _bgFade;

  @override
  void initState() {
    super.initState();

    _mainCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _bgFade = CurvedAnimation(
      parent: _mainCtrl,
      curve: const Interval(0.00, 0.25, curve: Curves.easeIn),
    );

    _myFade = CurvedAnimation(
      parent: _mainCtrl,
      curve: const Interval(0.08, 0.30, curve: Curves.easeOut),
    );
    _mySlide = Tween<double>(begin: -30, end: 0).animate(CurvedAnimation(
      parent: _mainCtrl,
      curve: const Interval(0.08, 0.30, curve: Curves.easeOut),
    ));

    _abaFade = CurvedAnimation(
      parent: _mainCtrl,
      curve: const Interval(0.16, 0.38, curve: Curves.easeOut),
    );
    _abaSlide = Tween<double>(begin: 30, end: 0).animate(CurvedAnimation(
      parent: _mainCtrl,
      curve: const Interval(0.16, 0.38, curve: Curves.easeOut),
    ));

    // R drops from above with a bounce
    _RFade = CurvedAnimation(
      parent: _mainCtrl,
      curve: const Interval(0.28, 0.48, curve: Curves.easeOut),
    );
    _RBounce = Tween<double>(begin: -80, end: 0).animate(CurvedAnimation(
      parent: _mainCtrl,
      curve: const Interval(0.28, 0.62, curve: Curves.elasticOut),
    ));

    _tagFade = CurvedAnimation(
      parent: _mainCtrl,
      curve: const Interval(0.68, 0.88, curve: Curves.easeOut),
    );

    _mainCtrl.forward().then((_) => _navigate());
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    final auth = Provider.of<AuthService>(context, listen: false);
    await auth.loadToken();
    if (!mounted) return;
    Widget next;
    if (!auth.isLoggedIn) {
      next = const WelcomeScreen();
    } else if (auth.isAdmin) {
      next = const AdminDashboardScreen();
    } else {
      next = const MainScreen();
    }
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, __, ___) => next,
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
      transitionDuration: const Duration(milliseconds: 500),
    ));
  }

  @override
  void dispose() {
    _mainCtrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MyrabaColors.bg,
      body: AnimatedBuilder(
        animation: Listenable.merge([_mainCtrl, _shimmerCtrl]),
        builder: (_, __) => Stack(
          fit: StackFit.expand,
          children: [
            // ── Unicorn fullscreen watermark ─────────────────────
            Positioned.fill(
              child: Opacity(
                opacity: _bgFade.value * 0.22,
                child: Image.asset(
                  'assets/images/unicorn.jpg',
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),

            // ── Dark purple overlay to dim the image ─────────────
            Positioned.fill(
              child: Opacity(
                opacity: _bgFade.value,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFF0D0618).withValues(alpha: 0.82),
                        const Color(0xFF120822).withValues(alpha: 0.70),
                        const Color(0xFF0D0618).withValues(alpha: 0.88),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Radial glow ───────────────────────────────────────
            Opacity(
              opacity: _bgFade.value,
              child: CustomPaint(painter: _GlowPainter()),
            ),

            // ── Central content ───────────────────────────────────
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildWordmark(),
                  const SizedBox(height: 20),
                  Opacity(
                    opacity: _tagFade.value,
                    child: const Text(
                      'MONEY. REIMAGINED.',
                      style: TextStyle(
                        fontSize: 13,
                        color: MyrabaColors.textSecond,
                        letterSpacing: 3.0,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                  Opacity(
                    opacity: _tagFade.value,
                    child: _buildDots(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWordmark() {
    const style = TextStyle(
      fontSize: 56,
      fontWeight: FontWeight.w900,
      letterSpacing: 2,
      color: Colors.white,
    );

    return SizedBox(
      height: 74,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // "My" slides in from left — orange
          Opacity(
            opacity: _myFade.value,
            child: Transform.translate(
              offset: Offset(_mySlide.value, 0),
              child: ShaderMask(
                shaderCallback: (b) => const LinearGradient(
                  colors: [MyrabaColors.orange, Color(0xFFFFB347)],
                ).createShader(b),
                blendMode: BlendMode.srcIn,
                child: const Text('My', style: style),
              ),
            ),
          ),

          // "R" drops from above — purple
          Opacity(
            opacity: _RFade.value,
            child: Transform.translate(
              offset: Offset(0, _RBounce.value),
              child: ShaderMask(
                shaderCallback: (b) => const LinearGradient(
                  colors: [MyrabaColors.purple, Color(0xFFB47FFF)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ).createShader(b),
                blendMode: BlendMode.srcIn,
                child: const Text('R', style: style),
              ),
            ),
          ),

          // "aba" slides in from right — orange
          Opacity(
            opacity: _abaFade.value,
            child: Transform.translate(
              offset: Offset(_abaSlide.value, 0),
              child: ShaderMask(
                shaderCallback: (b) => const LinearGradient(
                  colors: [Color(0xFFFFB347), MyrabaColors.orange],
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

  Widget _buildDots() {
    return AnimatedBuilder(
      animation: _shimmerCtrl,
      builder: (_, __) {
        final t = _shimmerCtrl.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (t * 3.0 - i * 0.33).clamp(0.0, 1.0);
            final bounce = (phase < 0.5 ? phase : 1.0 - phase) * 2.0;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 5, height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: MyrabaColors.orange.withValues(alpha: 0.35 + 0.65 * bounce),
              ),
            );
          }),
        );
      },
    );
  }
}

// ── Radial background glow ─────────────────────────────────────────────
class _GlowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = RadialGradient(
          colors: [
            MyrabaColors.orange.withValues(alpha: 0.09),
            MyrabaColors.purple.withValues(alpha: 0.07),
            Colors.transparent,
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Rect.fromCenter(
          center: Offset(cx, cy),
          width: size.width * 1.8,
          height: size.height * 1.8,
        )),
    );
  }

  @override
  bool shouldRepaint(_GlowPainter _) => false;
}
