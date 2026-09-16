import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GlowingOrb extends StatefulWidget {
  final double size;
  const GlowingOrb({super.key, this.size = 140.0});

  @override
  State<GlowingOrb> createState() => _GlowingOrbState();
}

class _GlowingOrbState extends State<GlowingOrb>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double s = widget.size;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _controller.value;
        final pulse = math.sin(progress * 2 * math.pi) * 0.05 + 1.0;

        return SizedBox(
          width: s,
          height: s,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. Soft Aurora Glow behind
              Container(
                width: s * 1.1 * pulse,
                height: s * 1.1 * pulse,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.accentPurple.withValues(alpha: 0.35),
                      AppTheme.accentPink.withValues(alpha: 0.15),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),

              // 2. Outer Rotating Ring 1
              Transform.rotate(
                angle: progress * 2 * math.pi,
                child: Container(
                  width: s * 0.95,
                  height: s * 0.95,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.accentPurple.withValues(alpha: 0.25),
                      width: 1.5,
                    ),
                  ),
                ),
              ),

              // 3. Counter-rotating Ring 2
              Transform.rotate(
                angle: -progress * 2 * math.pi * 0.75,
                child: Container(
                  width: s * 0.82,
                  height: s * 0.82,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.accentPink.withValues(alpha: 0.2),
                      width: 1.2,
                    ),
                  ),
                ),
              ),

              // 4. Central Glowing Sphere
              Container(
                width: s * 0.65 * pulse,
                height: s * 0.65 * pulse,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    center: Alignment(-0.3, -0.3),
                    colors: [
                      Color(0xFFE879F9),
                      Color(0xFFC084FC),
                      Color(0xFFA855F7),
                      Color(0xFF6366F1),
                      Color(0xFF1E1B4B),
                    ],
                    stops: [0.0, 0.25, 0.55, 0.85, 1.0],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accentPurple.withValues(alpha: 0.5),
                      blurRadius: 30,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: AppTheme.accentPink.withValues(alpha: 0.4),
                      blurRadius: 15,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Specular Highlight
                    Positioned(
                      top: s * 0.12,
                      left: s * 0.14,
                      child: Container(
                        width: s * 0.18,
                        height: s * 0.1,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.all(
                            Radius.elliptical(s * 0.18, s * 0.1),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 5. Orbiting Particle 1
              _buildOrbitalParticle(
                progress: progress,
                radius: s * 0.46,
                speedMultiplier: 1.0,
                particleSize: 5.0,
                color: AppTheme.accentCyan,
              ),

              // 6. Orbiting Particle 2
              _buildOrbitalParticle(
                progress: progress + 0.33,
                radius: s * 0.42,
                speedMultiplier: -1.2,
                particleSize: 4.0,
                color: AppTheme.accentPink,
              ),

              // 7. Orbiting Particle 3
              _buildOrbitalParticle(
                progress: progress + 0.66,
                radius: s * 0.48,
                speedMultiplier: 0.8,
                particleSize: 4.5,
                color: AppTheme.accentPurple,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOrbitalParticle({
    required double progress,
    required double radius,
    required double speedMultiplier,
    required double particleSize,
    required Color color,
  }) {
    final angle = progress * 2 * math.pi * speedMultiplier;
    final x = math.cos(angle) * radius;
    final y = math.sin(angle) * radius;

    return Transform.translate(
      offset: Offset(x, y),
      child: Container(
        width: particleSize,
        height: particleSize,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.8),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}
