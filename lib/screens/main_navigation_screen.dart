import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/floating_pill_nav_bar.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import 'tools_hub_screen.dart';

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
  int _currentIndex = 0;
  bool _isDrawerOpen = false;

  @override
  Widget build(BuildContext context) {
    // Hide nav bar when sidebar/drawer is open on chat screen
    final hideNavBar = _isDrawerOpen && _currentIndex == 0;

    return Scaffold(
      backgroundColor: AppTheme.bgMain,
      body: Stack(
        children: [
          // Screen pages maintained via IndexedStack
          IndexedStack(
            index: _currentIndex,
            children: [
              ChatScreen(
                isDarkMode: widget.isDarkMode,
                onToggleTheme: widget.onToggleTheme,
                onDrawerChanged: (isOpen) {
                  if (_isDrawerOpen != isOpen) {
                    setState(() => _isDrawerOpen = isOpen);
                  }
                },
              ),
              const ToolsHubScreen(isRootTab: true),
              ProfileScreen(
                isDarkMode: widget.isDarkMode,
                onToggleTheme: widget.onToggleTheme,
              ),
            ],
          ),

          // Floating Pill Bottom Navigation Bar with smooth slide & fade transitions
          AnimatedSlide(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            offset: hideNavBar ? const Offset(0, 1.5) : Offset.zero,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: hideNavBar ? 0.0 : 1.0,
              child: IgnorePointer(
                ignoring: hideNavBar,
                child: FloatingPillNavBar(
                  currentIndex: _currentIndex,
                  onTap: (index) {
                    setState(() => _currentIndex = index);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
