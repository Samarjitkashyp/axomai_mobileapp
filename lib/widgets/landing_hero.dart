import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'glowing_orb.dart';

class LandingHero extends StatelessWidget {
  final String? username;
  const LandingHero({super.key, this.username});

  @override
  Widget build(BuildContext context) {
    final hasUser = username != null && username!.trim().isNotEmpty;
    final title = hasUser ? 'Hi, $username!' : "Hi, I'm Axom AI";

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 10),
            // Greeting Title
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  '👋',
                  style: TextStyle(fontSize: 24),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Subtitle
            const Text(
              'How can I help you today?',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 32),

            // Animated Glowing Orb
            const GlowingOrb(size: 150),

            const SizedBox(height: 28),

            // Hero Tagline matching chat.aiaxom.co.in
            Container(
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.55,
                    color: AppTheme.textSecondary,
                  ),
                  children: [
                    const TextSpan(text: 'Your AI workspace for '),
                    WidgetSpan(
                      child: ShaderMask(
                        shaderCallback: (bounds) =>
                            AppTheme.primaryGradient.createShader(bounds),
                        child: const Text(
                          'everything about Assam',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const TextSpan(
                      text:
                          ' — reasoning, document tools, imagery and research. Replies natively in ',
                    ),
                    WidgetSpan(
                      child: ShaderMask(
                        shaderCallback: (bounds) =>
                            AppTheme.primaryGradient.createShader(bounds),
                        child: const Text(
                          'Assamese (অসমীয়া)',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
