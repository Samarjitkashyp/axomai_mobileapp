import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'chat_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  const MainNavigationScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.isDarkMode ? AppTheme.bgMain : const Color(0xFFF8FAFC),
      body: ChatScreen(
        isDarkMode: widget.isDarkMode,
        onToggleTheme: widget.onToggleTheme,
      ),
    );
  }
}
