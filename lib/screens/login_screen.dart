import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glowing_orb.dart';
import 'loading_splash_screen.dart';
import 'main_navigation_screen.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;
  final bool isRoot;
  final bool isDarkMode;
  final VoidCallback? onToggleTheme;

  const LoginScreen({
    super.key,
    required this.onLoginSuccess,
    this.isRoot = false,
    this.isDarkMode = true,
    this.onToggleTheme,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoginMode = true;
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMsg;

  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onSuccessNavigate(AuthUser? user) {
    widget.onLoginSuccess();
    if (widget.isRoot) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => LoadingSplashScreen(
            user: user,
            isDarkMode: widget.isDarkMode,
            onToggleTheme: widget.onToggleTheme ?? () {},
          ),
        ),
      );
    } else {
      Navigator.pop(context);
    }
  }

  void _onSkip() {
    if (widget.isRoot) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MainNavigationScreen(
            isDarkMode: widget.isDarkMode,
            onToggleTheme: widget.onToggleTheme ?? () {},
          ),
        ),
      );
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _handleSubmit() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      setState(() => _errorMsg = 'Please enter your username/email and password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    if (_isLoginMode) {
      final res = await AuthService.login(
        username: username,
        password: password,
      );

      if (!mounted) return;

      if (res['success'] == true) {
        final user = res['user'] as AuthUser?;
        _onSuccessNavigate(user);
      } else {
        setState(() {
          _isLoading = false;
          _errorMsg = res['error'] as String? ?? 'Invalid credentials.';
        });
      }
    } else {
      final email = _emailController.text.trim();
      final confirmPass = _confirmPasswordController.text.trim();

      if (email.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMsg = 'Please enter a valid email address.';
        });
        return;
      }
      if (password != confirmPass) {
        setState(() {
          _isLoading = false;
          _errorMsg = 'Passwords do not match.';
        });
        return;
      }

      final res = await AuthService.register(
        username: username,
        email: email,
        password: password,
        confirmPassword: confirmPass,
      );

      if (!mounted) return;

      if (res['success'] == true) {
        final user = res['user'] as AuthUser?;
        _onSuccessNavigate(user);
      } else {
        setState(() {
          _isLoading = false;
          _errorMsg = res['error'] as String? ?? 'Registration failed.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgMain,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: !widget.isRoot,
        leading: widget.isRoot
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: AppTheme.textPrimary, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
        actions: [
          TextButton(
            onPressed: _onSkip,
            child: Text(
              widget.isRoot ? 'Explore as Guest' : 'Skip',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Glowing Center Mini Orb & Brand
                  const Center(child: GlowingOrb(size: 90)),
                  const SizedBox(height: 20),

                  Text(
                    _isLoginMode ? 'Welcome back' : 'Create your account',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isLoginMode
                        ? 'Log in with your website account to continue'
                        : 'Sign up to unlock personalized chats & history',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Error Banner
                  if (_errorMsg != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: AppTheme.errorRed.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppTheme.errorRed.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              color: AppTheme.errorRed, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMsg!,
                              style: const TextStyle(
                                  color: AppTheme.errorRed, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Username or Email
                  TextField(
                    controller: _usernameController,
                    style: const TextStyle(
                        fontSize: 14, color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      hintText: _isLoginMode
                          ? 'Email address or username'
                          : 'Choose a username',
                      hintStyle: const TextStyle(
                          color: AppTheme.textMuted, fontSize: 13.5),
                      prefixIcon: const Icon(Icons.person_outline_rounded,
                          size: 18, color: AppTheme.textSecondary),
                      filled: true,
                      fillColor: AppTheme.bgCard,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppTheme.borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppTheme.borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppTheme.accentPurple),
                      ),
                    ),
                  ),

                  if (!_isLoginMode) ...[
                    const SizedBox(height: 12),
                    // Email
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(
                          fontSize: 14, color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Email address',
                        hintStyle: const TextStyle(
                            color: AppTheme.textMuted, fontSize: 13.5),
                        prefixIcon: const Icon(Icons.mail_outline_rounded,
                            size: 18, color: AppTheme.textSecondary),
                        filled: true,
                        fillColor: AppTheme.bgCard,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AppTheme.borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AppTheme.borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AppTheme.accentPurple),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Password
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: const TextStyle(
                        fontSize: 14, color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Password',
                      hintStyle: const TextStyle(
                          color: AppTheme.textMuted, fontSize: 13.5),
                      prefixIcon: const Icon(Icons.lock_outline_rounded,
                          size: 18, color: AppTheme.textSecondary),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 18,
                          color: AppTheme.textMuted,
                        ),
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                      ),
                      filled: true,
                      fillColor: AppTheme.bgCard,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppTheme.borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppTheme.borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppTheme.accentPurple),
                      ),
                    ),
                  ),

                  if (!_isLoginMode) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: _obscurePassword,
                      style: const TextStyle(
                          fontSize: 14, color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Confirm password',
                        hintStyle: const TextStyle(
                            color: AppTheme.textMuted, fontSize: 13.5),
                        prefixIcon: const Icon(Icons.lock_outline_rounded,
                            size: 18, color: AppTheme.textSecondary),
                        filled: true,
                        fillColor: AppTheme.bgCard,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AppTheme.borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AppTheme.borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AppTheme.accentPurple),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Submit Button
                  InkWell(
                    onTap: _isLoading ? null : _handleSubmit,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.accentPurple.withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: _isLoading
                          ? const SpinKitRing(
                              color: Colors.white,
                              size: 18,
                              lineWidth: 2,
                            )
                          : Text(
                              _isLoginMode ? 'Continue' : 'Create Account',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Toggle mode link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isLoginMode
                            ? "Don't have an account?"
                            : 'Already have an account?',
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isLoginMode = !_isLoginMode;
                            _errorMsg = null;
                          });
                        },
                        child: Text(
                          _isLoginMode ? 'Sign up' : 'Log in',
                          style: const TextStyle(
                            color: AppTheme.accentPurple,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
