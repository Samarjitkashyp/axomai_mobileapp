import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class HeaderBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onOpenLeftDrawer;
  final VoidCallback onOpenRightDrawer;
  final VoidCallback onOpenTools;
  final VoidCallback onToggleTheme;
  final bool isDarkMode;

  const HeaderBar({
    super.key,
    required this.onOpenLeftDrawer,
    required this.onOpenRightDrawer,
    required this.onOpenTools,
    required this.onToggleTheme,
    required this.isDarkMode,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56.0);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode
            ? AppTheme.bgMain.withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.95),
        border: const Border(
          bottom: BorderSide(color: AppTheme.borderColor, width: 0.5),
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
                icon: const Icon(Icons.menu_rounded,
                    color: AppTheme.textPrimary, size: 22),
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
                  color: AppTheme.bgPill,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Axom AI',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
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

          // Right: Tools, Theme Toggle, Right Drawer
          Row(
            children: [
              // Tools Quick Button
              InkWell(
                onTap: onOpenTools,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.bgPill,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.build_rounded,
                          size: 13, color: AppTheme.textPrimary),
                      SizedBox(width: 4),
                      Text(
                        'Tools',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Theme Toggle Icon Button
              IconButton(
                icon: Icon(
                  isDarkMode ? Icons.wb_sunny_outlined : Icons.nightlight_round,
                  color: AppTheme.textSecondary,
                  size: 19,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                onPressed: onToggleTheme,
                tooltip: 'Toggle Theme',
              ),

              // Control Panel / Sliders Button
              IconButton(
                icon: const Icon(Icons.tune_rounded,
                    color: AppTheme.textSecondary, size: 19),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
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
