import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glowing_orb.dart';
import 'loading_splash_screen.dart';
import 'login_screen.dart';
import 'main_navigation_screen.dart';

class AuthGateScreen extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  const AuthGateScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen> {
  bool _isChecking = true;
  AuthUser? _user;

  @override
  void initState() {
    super.initState();
    _checkInitialAuth();
  }

  Future<void> _checkInitialAuth() async {
    try {
      final user = await AuthService.getCurrentUser();
      if (mounted) {
        setState(() {
          _user = user;
          _isChecking = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _user = AuthUser.guest();
          _isChecking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return Scaffold(
        backgroundColor: AppTheme.bgMain,
        body: const Center(
          child: GlowingOrb(size: 80),
        ),
      );
    }

    // If user is already authenticated (previously logged in) -> Instant zero-latency launch
    if (_user != null && _user!.isAuthenticated) {
      return MainNavigationScreen(
        isDarkMode: widget.isDarkMode,
        onToggleTheme: widget.onToggleTheme,
      );
    }

    // First time install or user is not logged in -> Show Login Page
    return LoginScreen(
      isRoot: true,
      isDarkMode: widget.isDarkMode,
      onToggleTheme: widget.onToggleTheme,
      onLoginSuccess: () {},
    );
  }
}
