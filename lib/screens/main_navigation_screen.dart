import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'chat_screen.dart';

class MainNavigationScreen extends StatelessWidget {
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  const MainNavigationScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgMain,
      body: ChatScreen(
        isDarkMode: isDarkMode,
        onToggleTheme: onToggleTheme,
      ),
    );
  }
}
