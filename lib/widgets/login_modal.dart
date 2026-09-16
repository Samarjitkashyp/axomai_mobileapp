import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class LoginModal extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const LoginModal({
    super.key,
    required this.onLoginSuccess,
  });

  @override
  State<LoginModal> createState() => _LoginModalState();
}

class _LoginModalState extends State<LoginModal> {
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

  Future<void> _handleSubmit() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      setState(() => _errorMsg = 'Please enter both username and password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    if (_isLoginMode) {
      // Login
      final res = await AuthService.login(
        username: username,
        password: password,
      );

      if (!mounted) return;

      if (res['success'] == true) {
        widget.onLoginSuccess();
        Navigator.pop(context);
      } else {
        setState(() {
          _isLoading = false;
          _errorMsg = res['error'] as String? ?? 'Invalid credentials.';
        });
      }
    } else {
      // Register
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
        widget.onLoginSuccess();
        Navigator.pop(context);
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
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppTheme.borderColor, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: AppTheme.accentPurple.withValues(alpha: 0.15),
              blurRadius: 20,
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Row with Close
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'A',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _isLoginMode ? 'Sign In' : 'Create Account',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: AppTheme.textSecondary, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Use your website account details to log in seamlessly.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Tab Switcher
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.bgPill,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                padding: const EdgeInsets.all(3),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _isLoginMode = true;
                          _errorMsg = null;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            gradient: _isLoginMode
                                ? AppTheme.primaryGradient
                                : null,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Sign In',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _isLoginMode
                                  ? Colors.white
                                  : AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _isLoginMode = false;
                          _errorMsg = null;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            gradient: !_isLoginMode
                                ? AppTheme.primaryGradient
                                : null,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Register',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: !_isLoginMode
                                  ? Colors.white
                                  : AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Error Banner
              if (_errorMsg != null) ...[
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppTheme.errorRed.withValues(alpha: 0.3),
                    ),
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
                            color: AppTheme.errorRed,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Username / Email Field
              TextField(
                controller: _usernameController,
                style: const TextStyle(
                    fontSize: 13.5, color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: _isLoginMode ? 'Username or Email' : 'Username',
                  labelStyle: const TextStyle(
                      color: AppTheme.textMuted, fontSize: 13),
                  prefixIcon: const Icon(Icons.person_outline_rounded,
                      size: 18, color: AppTheme.textSecondary),
                  filled: true,
                  fillColor: AppTheme.bgPill,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.accentPurple),
                  ),
                ),
              ),

              // Email Field (Register Only)
              if (!_isLoginMode) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(
                      fontSize: 13.5, color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    labelStyle: const TextStyle(
                        color: AppTheme.textMuted, fontSize: 13),
                    prefixIcon: const Icon(Icons.mail_outline_rounded,
                        size: 18, color: AppTheme.textSecondary),
                    filled: true,
                    fillColor: AppTheme.bgPill,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.borderColor),
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

              // Password Field
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: const TextStyle(
                    fontSize: 13.5, color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: const TextStyle(
                      color: AppTheme.textMuted, fontSize: 13),
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
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  filled: true,
                  fillColor: AppTheme.bgPill,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.accentPurple),
                  ),
                ),
              ),

              // Confirm Password (Register Only)
              if (!_isLoginMode) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: _obscurePassword,
                  style: const TextStyle(
                      fontSize: 13.5, color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    labelStyle: const TextStyle(
                        color: AppTheme.textMuted, fontSize: 13),
                    prefixIcon: const Icon(Icons.lock_outline_rounded,
                        size: 18, color: AppTheme.textSecondary),
                    filled: true,
                    fillColor: AppTheme.bgPill,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.borderColor),
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
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accentPurple.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
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
                          _isLoginMode ? 'Sign In' : 'Create Account',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 14),

              // Continue as Guest
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Continue as Guest',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
