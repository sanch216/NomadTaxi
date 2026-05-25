import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_theme.dart';

/// Full-screen overlay with a glowing radar animation,
/// shown while searching for a driver.
class FindingDriverOverlay extends StatefulWidget {
  final VoidCallback onCancel;

  const FindingDriverOverlay({super.key, required this.onCancel});

  @override
  State<FindingDriverOverlay> createState() => _FindingDriverOverlayState();
}

class _FindingDriverOverlayState extends State<FindingDriverOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _rotateController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Dark semi-transparent base ────────────────────────────
        Container(color: Colors.black.withValues(alpha: 0.72)),

        // ── Vignette — darker at edges, lighter at centre ─────────
        Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.1,
              colors: [
                Color(0x00000000), // transparent centre
                Color(0xCC000000), // dark at edges
              ],
              stops: [0.35, 1.0],
            ),
          ),
        ),

        // ── Content ───────────────────────────────────────────────
        SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),

              // ── Radar animation ──────────────────────────────────
              SizedBox(
                width: 260,
                height: 260,
                child: AnimatedBuilder(
                  animation: Listenable.merge([
                    _pulseController,
                    _rotateController,
                  ]),
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _RadarPainter(
                        pulseProgress: _pulseController.value,
                        rotateProgress: _rotateController.value,
                      ),
                      child: Center(
                        // ── Center glowing circle ────────────────
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF4FC3F7,
                                ).withValues(alpha: 0.9),
                                blurRadius: 24,
                                spreadRadius: 6,
                              ),
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.4),
                                blurRadius: 40,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.local_taxi_rounded,
                            color: AppTheme.primaryNavy,
                            size: 30,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 40),

              // ── Text ─────────────────────────────────────────────
              Text(
                'Поиск водителя...',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: const Color(0xFF4FC3F7).withValues(alpha: 0.6),
                      blurRadius: 12,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Обычно это занимает менее минуты',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.65),
                ),
              ),

              const Spacer(flex: 3),

              // ── Cancel button ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 40),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: widget.onCancel,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.4),
                        width: 1.2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.buttonRadius,
                        ),
                      ),
                    ),
                    child: Text(
                      'Отменить',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Radar CustomPainter ─────────────────────────────────────────────────────

class _RadarPainter extends CustomPainter {
  final double pulseProgress;
  final double rotateProgress;

  // Glow colour: bright cyan-blue
  static const _ringColor = Color(0xFF4FC3F7);

  _RadarPainter({required this.pulseProgress, required this.rotateProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // ── Glowing expanding rings ──────────────────────────────────
    for (int i = 0; i < 3; i++) {
      final stagger = i / 3;
      final progress = (pulseProgress + stagger) % 1.0;
      final radius = maxRadius * progress;
      final opacity = (1.0 - progress).clamp(0.0, 0.75);

      // Outer glow (wide, soft)
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = _ringColor.withValues(alpha: opacity * 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10.0
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );

      // Inner sharp ring
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = _ringColor.withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    // ── Glowing sweep line ────────────────────────────────────────
    final sweepAngle = rotateProgress * 2 * math.pi;
    final sweepEnd = Offset(
      center.dx + maxRadius * 0.72 * math.cos(sweepAngle),
      center.dy + maxRadius * 0.72 * math.sin(sweepAngle),
    );

    // Glow version
    canvas.drawLine(
      center,
      sweepEnd,
      Paint()
        ..shader = LinearGradient(
          colors: [
            _ringColor.withValues(alpha: 0.0),
            _ringColor.withValues(alpha: 0.6),
          ],
        ).createShader(Rect.fromPoints(center, sweepEnd))
        ..strokeWidth = 6
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // Sharp version
    canvas.drawLine(
      center,
      sweepEnd,
      Paint()
        ..shader = LinearGradient(
          colors: [
            _ringColor.withValues(alpha: 0.0),
            _ringColor.withValues(alpha: 0.85),
          ],
        ).createShader(Rect.fromPoints(center, sweepEnd))
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) => true;
}
