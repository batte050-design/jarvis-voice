import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The four behavioural states of the JARVIS hologram.
enum HologramState { idle, listening, thinking, speaking }

/// A glowing teal "reactor core" hologram: a rotating particle ring, an inner
/// frame ring, and a 3D point-cloud sphere with a reticle. The single
/// AnimationController drives all four states by varying spin speed, glow and
/// ring scale. The "speaking" state ripples the rings to mimic a voice
/// visualizer (time-synced to the TTS audio rather than amplitude-driven).
class JarvisHologram extends StatefulWidget {
  const JarvisHologram({super.key, required this.state, this.size = 280});

  final HologramState state;
  final double size;

  @override
  State<JarvisHologram> createState() => _JarvisHologramState();
}

class _JarvisHologramState extends State<JarvisHologram>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  Duration _durationFor(HologramState s) {
    switch (s) {
      case HologramState.idle:
        return const Duration(seconds: 5);
      case HologramState.listening:
        return const Duration(milliseconds: 900);
      case HologramState.thinking:
        return const Duration(milliseconds: 650);
      case HologramState.speaking:
        return const Duration(milliseconds: 500);
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _durationFor(HologramState.idle),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant JarvisHologram oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _controller.duration = _durationFor(widget.state);
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          size: Size.square(widget.size),
          painter: _HologramPainter(state: widget.state, t: _controller.value),
        );
      },
    );
  }
}

class _Point3 {
  const _Point3(this.x, this.y, this.z);
  final double x, y, z;
}

/// Evenly distributed points on a unit sphere (Fibonacci lattice).
List<_Point3> _fibonacciSphere(int n) {
  final pts = <_Point3>[];
  final golden = math.pi * (3 - math.sqrt(5));
  for (var i = 0; i < n; i++) {
    final y = 1 - (i / (n - 1)) * 2;
    final r = math.sqrt(1 - y * y);
    final theta = golden * i;
    pts.add(_Point3(math.cos(theta) * r, y, math.sin(theta) * r));
  }
  return pts;
}

class _HologramPainter extends CustomPainter {
  _HologramPainter({required this.state, required this.t});

  final HologramState state;
  final double t;

  static const _accent = Color(0xFF00E5FF); // electric cyan
  static const _teal = Color(0xFF2DD4BF);
  static const _bg = Color(0xFF05080F);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final cx = center.dx;
    final cy = center.dy;
    final maxR = size.shortestSide / 2;

    // Vignette background: slightly lighter teal-tinted centre fading to black.
    final vignette = Paint()
      ..shader = RadialGradient(
        colors: const [Color(0xFF0A1B26), _bg],
        stops: const [0.0, 0.8],
      ).createShader(Rect.fromCircle(center: center, radius: maxR));
    canvas.drawCircle(center, maxR, vignette);

    // Per-state animation parameters.
    double spin, pulse, glow, ringScale;
    switch (state) {
      case HologramState.idle:
        spin = 0.06;
        pulse = 0.05;
        glow = 0.35;
        ringScale = 1.0;
        break;
      case HologramState.listening:
        spin = 0.5;
        pulse = 0.18;
        glow = 0.85;
        ringScale = 0.94;
        break;
      case HologramState.thinking:
        spin = 1.2;
        pulse = 0.12;
        glow = 0.65;
        ringScale = 1.0;
        break;
      case HologramState.speaking:
        spin = 0.3;
        pulse = 0.0;
        glow = 0.95;
        ringScale = 1.05;
        break;
    }

    final breathe = 1 + pulse * math.sin(t * 2 * math.pi);

    // Outer holographic particle ring — dots on a circle, each with a slight
    // radius jitter and size shimmer for the "light particle" texture.
    final outerR = maxR * 0.88 * ringScale * breathe;
    const nParticles = 72;
    final dotPaint = Paint()
      ..color = _accent.withValues(alpha: 0.9)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
    for (var i = 0; i < nParticles; i++) {
      final a = (i / nParticles) * 2 * math.pi + t * spin * 2 * math.pi;
      final jitter = 1 + 0.03 * math.sin(i * 7.3 + t * 20);
      final r = outerR * jitter;
      final dx = cx + r * math.cos(a);
      final dy = cy + r * math.sin(a);
      final d = 2.2 + 1.6 * math.sin(i * 2.7 + t * 15);
      canvas.drawCircle(Offset(dx, dy), d, dotPaint);
    }

    // Inner frame ring.
    final innerR = maxR * 0.60 * ringScale;
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = _accent.withValues(alpha: 0.25 + 0.45 * glow)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawCircle(center, innerR, ringPaint);

    // Speaking: expanding ripple rings (voice visualizer, time-based).
    if (state == HologramState.speaking) {
      for (var k = 0; k < 3; k++) {
        final phase = (t + k / 3) % 1.0;
        final rr = innerR * (1 + phase * 0.55);
        final alpha = (1 - phase) * 0.7;
        final ripplePaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..color = _teal.withValues(alpha: alpha);
        canvas.drawCircle(center, rr, ripplePaint);
      }
    }

    // Central point-cloud sphere (rotating 3D projection).
    final sphereR = maxR * 0.34 * ringScale;
    final pts = _fibonacciSphere(140);
    final rot = t * spin * 3;
    for (final p in pts) {
      final ca = math.cos(rot);
      final sa = math.sin(rot);
      final x = p.x * ca + p.z * sa;
      final y = p.y;
      final z = -p.x * sa + p.z * ca;
      final depth = (z + 1) / 2; // 0 (back) .. 1 (front)
      final d = 1.1 + depth * 2.0;
      final alpha = 0.25 + depth * 0.6;
      final dot = Paint()
        ..color = _accent.withValues(alpha: alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1);
      canvas.drawCircle(Offset(cx + x * sphereR, cy + y * sphereR), d, dot);
    }

    // Soft core glow behind the sphere.
    final coreGlow = Paint()
      ..shader = RadialGradient(
        colors: [
          _accent.withValues(alpha: 0.5 * glow),
          _accent.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: sphereR * 1.7));
    canvas.drawCircle(center, sphereR * 1.7, coreGlow);

    // Reticle crosshair.
    final reticle = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(cx - sphereR * 1.3, cy),
      Offset(cx + sphereR * 1.3, cy),
      reticle,
    );
    canvas.drawLine(
      Offset(cx, cy - sphereR * 1.3),
      Offset(cx, cy + sphereR * 1.3),
      reticle,
    );
  }

  @override
  bool shouldRepaint(covariant _HologramPainter oldDelegate) =>
      oldDelegate.state != state || oldDelegate.t != t;
}
