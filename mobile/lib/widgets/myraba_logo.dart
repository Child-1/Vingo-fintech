import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ─── Public widget ────────────────────────────────────────────────
/// Animated or static Myraba alicorn logo mark.
/// [wingSpread] 0→1 animates wings unfolding.
/// [hornRise]   0→1 animates horn growing upward.
/// [glowAlpha]  0→1 controls the ambient glow intensity.
class MyrabaLogoMark extends StatelessWidget {
  final double size;
  final double wingSpread;
  final double hornRise;
  final double glowAlpha;

  const MyrabaLogoMark({
    super.key,
    this.size = 120,
    this.wingSpread = 1.0,
    this.hornRise   = 1.0,
    this.glowAlpha  = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _AlicornPainter(
          wingSpread: wingSpread,
          hornRise:   hornRise,
          glowAlpha:  glowAlpha,
        ),
      ),
    );
  }
}

// ─── Animated wrapper ─────────────────────────────────────────────
class AnimatedMyrabaLogo extends StatefulWidget {
  final double size;
  final Duration duration;
  final bool autoPlay;

  const AnimatedMyrabaLogo({
    super.key,
    this.size     = 120,
    this.duration = const Duration(milliseconds: 1600),
    this.autoPlay = true,
  });

  @override
  State<AnimatedMyrabaLogo> createState() => AnimatedMyrabaLogoState();
}

class AnimatedMyrabaLogoState extends State<AnimatedMyrabaLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _wingAnim;
  late Animation<double> _hornAnim;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);

    _glowAnim = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
    );
    _wingAnim = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.15, 0.75, curve: Curves.easeOutBack),
    );
    _hornAnim = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.6, 0.95, curve: Curves.easeOutCubic),
    );

    if (widget.autoPlay) _ctrl.forward();
  }

  void play() => _ctrl.forward(from: 0);

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => MyrabaLogoMark(
        size:       widget.size,
        wingSpread: _wingAnim.value,
        hornRise:   _hornAnim.value,
        glowAlpha:  _glowAnim.value,
      ),
    );
  }
}

// ─── CustomPainter ────────────────────────────────────────────────
class _AlicornPainter extends CustomPainter {
  final double wingSpread;
  final double hornRise;
  final double glowAlpha;

  const _AlicornPainter({
    required this.wingSpread,
    required this.hornRise,
    required this.glowAlpha,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w  = size.width;
    final h  = size.height;
    final cx = w * 0.5;
    final cy = h * 0.56;          // center of body oval

    _drawGlow(canvas, cx, cy, w, h);
    _drawWings(canvas, cx, cy, w, h);
    _drawBody(canvas, cx, cy, w, h);
    _drawHorn(canvas, cx, cy, h);
    _drawBodyHighlight(canvas, cx, cy);
  }

  // ── 1. Ambient glow ──────────────────────────────────────────────
  void _drawGlow(Canvas canvas, double cx, double cy, double w, double h) {
    if (glowAlpha <= 0) return;

    // orange outer glow
    final outerPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          MyrabaColors.orange.withValues(alpha: 0.28 * glowAlpha),
          MyrabaColors.purple.withValues(alpha: 0.14 * glowAlpha),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCenter(
        center: Offset(cx, cy - h * 0.06),
        width: w * 1.1,
        height: h * 1.1,
      ));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), outerPaint);

    // tight inner glow behind body
    final innerPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          MyrabaColors.purple.withValues(alpha: 0.45 * glowAlpha),
          Colors.transparent,
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCenter(
        center: Offset(cx, cy),
        width: w * 0.5,
        height: h * 0.5,
      ));
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: w * 0.5, height: h * 0.5),
      innerPaint,
    );
  }

  // ── 2. Wings ─────────────────────────────────────────────────────
  void _drawWings(Canvas canvas, double cx, double cy, double w, double h) {
    if (wingSpread <= 0) return;

    final s = wingSpread;           // 0 → 1
    final wPaint = Paint()
      ..color = MyrabaColors.orange.withValues(alpha: s)
      ..style = PaintingStyle.fill;

    // shadow under wings
    final shadowPaint = Paint()
      ..color = MyrabaColors.greenDeep.withValues(alpha: 0.4 * s)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    for (final isLeft in [true, false]) {
      final path = _buildWingPath(cx, cy, w, h, s, isLeft);
      canvas.drawPath(path, shadowPaint);
      canvas.drawPath(path, wPaint);

      // lighter inner highlight on each wing
      final highlightPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.12 * s)
        ..style = PaintingStyle.fill;
      canvas.drawPath(_buildWingHighlight(cx, cy, w, h, s, isLeft), highlightPaint);
    }
  }

  Path _buildWingPath(double cx, double cy, double w, double h,
      double s, bool isLeft) {
    final sign = isLeft ? -1.0 : 1.0;
    final root = Offset(cx + sign * w * 0.08, cy - h * 0.02);

    // how far the tip travels
    final tipX = cx + sign * w * 0.46 * s;
    final tipY = cy - h * 0.42 * s;

    final path = Path();
    path.moveTo(root.dx, root.dy);

    // ── leading (lower) edge: smooth cubic sweep ──
    path.cubicTo(
      cx + sign * w * 0.18 * s, cy - h * 0.10 * s,
      cx + sign * w * 0.34 * s, cy - h * 0.26 * s,
      tipX, tipY,
    );

    // ── trailing (upper) edge: 4 feather notches ──
    final notches = isLeft
        ? _leftNotches(cx, cy, w, h, s, tipX, tipY)
        : _rightNotches(cx, cy, w, h, s, tipX, tipY);

    for (final pt in notches) {
      path.lineTo(pt.dx, pt.dy);
    }

    path.close();
    return path;
  }

  // Left-wing feather notches (trail from tip back to root)
  List<Offset> _leftNotches(double cx, double cy, double w, double h,
      double s, double tipX, double tipY) {
    return [
      Offset(tipX + w * 0.04 * s, tipY + h * 0.07 * s),   // feather 1 valley
      Offset(tipX + w * 0.01 * s, tipY + h * 0.13 * s),   // feather 1 peak
      Offset(tipX + w * 0.07 * s, tipY + h * 0.19 * s),   // feather 2 valley
      Offset(tipX + w * 0.04 * s, tipY + h * 0.26 * s),   // feather 2 peak
      Offset(cx - w * 0.26 * s,   cy - h * 0.09 * s),     // feather 3 valley
      Offset(cx - w * 0.21 * s,   cy - h * 0.02 * s),     // feather 3 peak (near root)
    ];
  }

  List<Offset> _rightNotches(double cx, double cy, double w, double h,
      double s, double tipX, double tipY) {
    return [
      Offset(tipX - w * 0.04 * s, tipY + h * 0.07 * s),
      Offset(tipX - w * 0.01 * s, tipY + h * 0.13 * s),
      Offset(tipX - w * 0.07 * s, tipY + h * 0.19 * s),
      Offset(tipX - w * 0.04 * s, tipY + h * 0.26 * s),
      Offset(cx + w * 0.26 * s,   cy - h * 0.09 * s),
      Offset(cx + w * 0.21 * s,   cy - h * 0.02 * s),
    ];
  }

  // Thin highlight stroke on leading edge
  Path _buildWingHighlight(double cx, double cy, double w, double h,
      double s, bool isLeft) {
    final sign = isLeft ? -1.0 : 1.0;
    final root = Offset(cx + sign * w * 0.08, cy - h * 0.02);
    final tipX = cx + sign * w * 0.44 * s;
    final tipY = cy - h * 0.40 * s;
    final path = Path();
    path.moveTo(root.dx, root.dy);
    path.cubicTo(
      cx + sign * w * 0.16 * s, cy - h * 0.08 * s,
      cx + sign * w * 0.30 * s, cy - h * 0.22 * s,
      tipX, tipY,
    );
    path.cubicTo(
      cx + sign * w * 0.32 * s, cy - h * 0.24 * s,
      cx + sign * w * 0.18 * s, cy - h * 0.10 * s,
      cx + sign * w * 0.10, cy - h * 0.03,
    );
    path.close();
    return path;
  }

  // ── 3. Body silhouette (dark oval + purple rim) ──────────────────
  void _drawBody(Canvas canvas, double cx, double cy, double w, double h) {
    final bodyRect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: w * 0.38,
      height: h * 0.45,
    );

    // Dark fill
    final fillPaint = Paint()
      ..color = MyrabaColors.bg
      ..style = PaintingStyle.fill;
    canvas.drawOval(bodyRect, fillPaint);

    // Purple rim glow
    final rimPaint = Paint()
      ..color = MyrabaColors.purple.withValues(alpha: 0.7 * glowAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawOval(bodyRect, rimPaint);
  }

  // ── 4. Horn ──────────────────────────────────────────────────────
  void _drawHorn(Canvas canvas, double cx, double cy, double h) {
    if (hornRise <= 0) return;

    final hornBase = cy - h * 0.215;         // top of body oval
    final hornTipY = hornBase - h * 0.28 * hornRise;

    final hornPaint = Paint()
      ..color = MyrabaColors.orange.withValues(alpha: hornRise)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(cx - 5, hornBase);
    path.lineTo(cx + 5, hornBase);
    path.lineTo(cx,     hornTipY);
    path.close();
    canvas.drawPath(path, hornPaint);

    // Glow on horn
    if (hornRise > 0.5) {
      final glowPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            MyrabaColors.orange.withValues(alpha: 0.0),
            MyrabaColors.orange.withValues(alpha: 0.35 * hornRise),
          ],
        ).createShader(Rect.fromLTWH(cx - 10, hornTipY, 20, hornBase - hornTipY))
        ..style = PaintingStyle.fill;
      final gPath = Path();
      gPath.moveTo(cx - 12, hornBase);
      gPath.lineTo(cx + 12, hornBase);
      gPath.lineTo(cx, hornTipY - h * 0.04);
      gPath.close();
      canvas.drawPath(gPath, glowPaint);
    }
  }

  // ── 5. Tiny "V" highlight on body ────────────────────────────────
  void _drawBodyHighlight(Canvas canvas, double cx, double cy) {
    if (glowAlpha <= 0) return;
    final paint = Paint()
      ..color = MyrabaColors.orange.withValues(alpha: 0.55 * glowAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final top   = cy - 10.0;
    final bot   = cy + 10.0;
    final left  = cx - 8.0;
    final right = cx + 8.0;
    path.moveTo(left,  top);
    path.lineTo(cx,    bot);
    path.lineTo(right, top);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_AlicornPainter old) =>
      old.wingSpread != wingSpread ||
      old.hornRise   != hornRise   ||
      old.glowAlpha  != glowAlpha;
}

// ─── Full logo (mark + wordmark) ─────────────────────────────────
class MyrabaFullLogo extends StatelessWidget {
  final double markSize;
  final double wingSpread;
  final double hornRise;
  final double glowAlpha;
  final double wordmarkOpacity;

  const MyrabaFullLogo({
    super.key,
    this.markSize        = 100,
    this.wingSpread      = 1.0,
    this.hornRise        = 1.0,
    this.glowAlpha       = 1.0,
    this.wordmarkOpacity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MyrabaLogoMark(
          size:       markSize,
          wingSpread: wingSpread,
          hornRise:   hornRise,
          glowAlpha:  glowAlpha,
        ),
        if (wordmarkOpacity > 0) ...[
          const SizedBox(height: 14),
          Opacity(
            opacity: wordmarkOpacity.clamp(0.0, 1.0),
            child: _buildWordmark(),
          ),
        ],
      ],
    );
  }

  Widget _buildWordmark() {
    // "VIN" in white + "GO" in orange, separated into two styled spans
    return RichText(
      text: const TextSpan(
        children: [
          TextSpan(
            text: 'VIN',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 4,
            ),
          ),
          TextSpan(
            text: 'GO',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: MyrabaColors.orange,
              letterSpacing: 4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Spinning stars / particles helper ────────────────────────────
class MyrabaParticlePainter extends CustomPainter {
  final double progress;   // 0→1
  final double alpha;

  const MyrabaParticlePainter({required this.progress, required this.alpha});

  @override
  void paint(Canvas canvas, Size size) {
    if (alpha <= 0) return;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final paint = Paint()..style = PaintingStyle.fill;

    const count = 12;
    for (int i = 0; i < count; i++) {
      final angle  = (i / count) * math.pi * 2 + progress * math.pi * 2;
      final radius = size.width * 0.42;
      final spread = math.sin(progress * math.pi * 4 + i) * 0.12 + 0.88;
      final x = cx + math.cos(angle) * radius * spread;
      final y = cy + math.sin(angle) * radius * spread;

      final dotR = (i.isEven ? 2.5 : 1.8) * alpha;
      final color = i % 3 == 0
          ? MyrabaColors.orange.withValues(alpha: 0.7 * alpha)
          : i % 3 == 1
              ? MyrabaColors.purple.withValues(alpha: 0.5 * alpha)
              : Colors.white.withValues(alpha: 0.3 * alpha);

      paint.color = color;
      canvas.drawCircle(Offset(x, y), dotR, paint);
    }
  }

  @override
  bool shouldRepaint(MyrabaParticlePainter old) =>
      old.progress != progress || old.alpha != alpha;
}
