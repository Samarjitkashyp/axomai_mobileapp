import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glowing_orb.dart';
import 'main_navigation_screen.dart';

class LoadingSplashScreen extends StatefulWidget {
  final AuthUser? user;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;
  final VoidCallback? onFinished;

  const LoadingSplashScreen({
    super.key,
    this.user,
    required this.isDarkMode,
    required this.onToggleTheme,
    this.onFinished,
  });

  @override
  State<LoadingSplashScreen> createState() => _LoadingSplashScreenState();
}

class _LoadingSplashScreenState extends State<LoadingSplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  String _statusText = 'Verifying neural credentials...';
  int _statusStep = 0;
  Timer? _statusTimer;

  final List<String> _statusMessages = [
    'Verifying neural credentials...',
    'Connecting to Axom AI cloud...',
    'Restoring personalized workspace...',
    'Ready! Launching experience...',
  ];

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: Curves.easeOutCubic,
      ),
    );

    _fadeController.forward();
    _startLoadingSequence();
  }

  void _startLoadingSequence() {
    // Cycle through status messages
    _statusTimer = Timer.periodic(const Duration(milliseconds: 450), (timer) {
      if (!mounted) return;
      if (_statusStep < _statusMessages.length - 1) {
        setState(() {
          _statusStep++;
          _statusText = _statusMessages[_statusStep];
        });
      }
    });

    // Run auth sync & allow minimum animation duration
    Future.wait([
      AuthService.syncUserStatus(),
      Future.delayed(const Duration(milliseconds: 1900)),
    ]).then((_) {
      if (!mounted) return;
      _proceedToApp();
    }).catchError((_) {
      if (!mounted) return;
      _proceedToApp();
    });
  }

  void _proceedToApp() {
    if (widget.onFinished != null) {
      widget.onFinished!();
      return;
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (context, animation, secondaryAnimation) =>
            MainNavigationScreen(
          isDarkMode: widget.isDarkMode,
          onToggleTheme: widget.onToggleTheme,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          );
          return FadeTransition(
            opacity: curved,
            child: child,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final displayName = user != null && user.name.trim().isNotEmpty
        ? user.name.trim()
        : (user?.username.trim().isNotEmpty ?? false)
            ? user!.username.trim()
            : null;

    return Scaffold(
      backgroundColor: AppTheme.bgMain,
      body: Stack(
        children: [
          // Background subtle ambient radial gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.0, -0.2),
                  radius: 0.9,
                  colors: [
                    AppTheme.accentPurple.withValues(alpha: 0.12),
                    AppTheme.accentPink.withValues(alpha: 0.05),
                    AppTheme.bgMain,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),

          // Main Animated Center Content
          SafeArea(
            child: Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Central Glowing Animated Orb
                        const GlowingOrb(size: 130),
                        const SizedBox(height: 36),

                        // Title with glowing shader gradient
                        ShaderMask(
                          shaderCallback: (bounds) =>
                              AppTheme.primaryGradient.createShader(bounds),
                          child: Text(
                            'AXOM AI',
                            style: GoogleFonts.outfit(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 3.5,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Greeting / User status
                        if (displayName != null) ...[
                          Container(
                            constraints: const BoxConstraints(maxWidth: 300),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.accentPurple.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppTheme.accentPurple.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.verified_user_rounded,
                                  size: 14,
                                  color: AppTheme.accentPurple,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'Welcome back, $displayName',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Dynamic status text
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: Text(
                            _statusText,
                            key: ValueKey<String>(_statusText),
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Three-bounce indicator
                        const SpinKitThreeBounce(
                          color: AppTheme.accentPurple,
                          size: 22,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Bottom brand footer
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'Next-Gen AI Platform • Secure Session',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textMuted.withValues(alpha: 0.7),
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
