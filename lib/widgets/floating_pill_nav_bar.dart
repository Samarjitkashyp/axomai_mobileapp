import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class FloatingPillNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const FloatingPillNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Hide nav bar when on-screen keyboard is open
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    if (isKeyboardOpen) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16.0, left: 32.0, right: 32.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                height: 62,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xE60E1022), // 90% opacity deep dark
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: AppTheme.accentPurple.withValues(alpha: 0.12),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildNavItem(
                      index: 0,
                      icon: Icons.chat_bubble_outline_rounded,
                      activeIcon: Icons.chat_bubble_rounded,
                      label: 'Chat',
                    ),
                    _buildNavItem(
                      index: 1,
                      icon: Icons.grid_view_rounded,
                      activeIcon: Icons.grid_view_rounded,
                      label: 'Tools',
                    ),
                    _buildNavItem(
                      index: 2,
                      icon: Icons.person_outline_rounded,
                      activeIcon: Icons.person_rounded,
                      label: 'Profile',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final isActive = currentIndex == index;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            gradient: isActive
                ? const LinearGradient(
                    colors: [AppTheme.accentPurple, AppTheme.accentViolet],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isActive ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppTheme.accentPurple.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isActive ? activeIcon : icon,
                size: 20,
                color: isActive ? Colors.white : AppTheme.textMuted,
              ),
              if (isActive) ...[
                const SizedBox(width: 7),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
