import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class HeaderBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onOpenLeftDrawer;
  final VoidCallback onOpenRightDrawer;
  final VoidCallback onToggleTheme;
  final bool isDarkMode;

  const HeaderBar({
    super.key,
    required this.onOpenLeftDrawer,
    required this.onOpenRightDrawer,
    required this.onToggleTheme,
    required this.isDarkMode,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56.0);

  @override
  Widget build(BuildContext context) {
    final bgColor = isDarkMode ? AppTheme.bgMain : Colors.white;
    final borderColor = isDarkMode ? AppTheme.borderColor : const Color(0xFFE2E8F0);
    final textPrimaryColor = isDarkMode ? AppTheme.textPrimary : const Color(0xFF0F172A);
    final textSecondaryColor = isDarkMode ? AppTheme.textSecondary : const Color(0xFF475569);
    final pillBg = isDarkMode ? AppTheme.bgPill : const Color(0xFFF1F5F9);
    final pillBorder = isDarkMode ? AppTheme.borderColor : const Color(0xFFE2E8F0);

    return Container(
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.95),
        border: Border(
          bottom: BorderSide(color: borderColor, width: 0.5),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left: Menu Icon + Model Selector Pill
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.menu_rounded,
                        color: textPrimaryColor, size: 22),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    onPressed: onOpenLeftDrawer,
                    tooltip: 'Chat History',
                  ),
                  const SizedBox(width: 8),

                  // Model Selector Pill matching chat.aiaxom.co.in
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: pillBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: pillBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Axom AI',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: textPrimaryColor,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Assam AI',
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Right: Theme Toggle & Control Panel (Tools removed as requested)
              Row(
                children: [
                  // Theme Toggle Icon Button
                  IconButton(
                    icon: Icon(
                      isDarkMode ? Icons.wb_sunny_outlined : Icons.nightlight_round,
                      color: isDarkMode ? AppTheme.accentAmber : const Color(0xFF6366F1),
                      size: 20,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    onPressed: onToggleTheme,
                    tooltip: isDarkMode ? 'Switch to Light Theme' : 'Switch to Dark Theme',
                  ),
                  const SizedBox(width: 4),

                  // Control Panel / Sliders Button
                  IconButton(
                    icon: Icon(Icons.tune_rounded,
                        color: textSecondaryColor, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    onPressed: onOpenRightDrawer,
                    tooltip: 'Account & Plan Controls',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
