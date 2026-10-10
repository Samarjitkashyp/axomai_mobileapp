import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../theme/app_theme.dart';

class InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final bool webSearch;
  final bool isAssameseTranslit;
  final VoidCallback onToggleWebSearch;
  final VoidCallback onToggleTranslit;
  final VoidCallback onOpenTools;
  final VoidCallback onPickAttachment;
  final VoidCallback onSend;
  final double? bottomPadding;

  const InputBar({
    super.key,
    required this.controller,
    required this.isLoading,
    required this.webSearch,
    this.isAssameseTranslit = false,
    required this.onToggleWebSearch,
    required this.onToggleTranslit,
    required this.onOpenTools,
    required this.onPickAttachment,
    required this.onSend,
    this.bottomPadding,
  });

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final effectiveBottom = isKeyboardOpen
        ? (safeBottom + 8)
        : ((bottomPadding ?? 92) + safeBottom);

    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 6,
        bottom: effectiveBottom,
      ),
      decoration: BoxDecoration(
        color: AppTheme.bgMain.withValues(alpha: 0.95),
        border: const Border(
          top: BorderSide(color: AppTheme.borderColor, width: 0.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Input Card Container
          Container(
            decoration: BoxDecoration(
              color: AppTheme.bgInput,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isAssameseTranslit
                    ? AppTheme.accentPurple.withOpacity(0.5)
                    : AppTheme.borderColor,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Row: Attachment & Text Input
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.add_photo_alternate_rounded,
                          color: AppTheme.textSecondary, size: 21),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: onPickAttachment,
                      tooltip: 'Attach Image / OCR',
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minHeight: 36,
                          maxHeight: 120,
                        ),
                        child: TextField(
                          controller: controller,
                          maxLines: 4,
                          minLines: 1,
                          textInputAction: TextInputAction.newline,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14.5,
                          ),
                          decoration: InputDecoration(
                            hintText: isAssameseTranslit
                                ? 'অসমীয়াত লিখক (e.g. axom)...'
                                : 'Message Axom AI...',
                            hintStyle: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 14.5,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // Bottom Controls Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Left Control Pills
                    Row(
                      children: [
                        // Assamese Transliteration Toggle Pill
                        InkWell(
                          onTap: onToggleTranslit,
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isAssameseTranslit
                                  ? AppTheme.accentPurple.withOpacity(0.2)
                                  : AppTheme.bgPill,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isAssameseTranslit
                                    ? AppTheme.accentPurple.withOpacity(0.6)
                                    : AppTheme.borderColor,
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  'অ',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isAssameseTranslit
                                        ? AppTheme.accentPurple
                                        : AppTheme.textSecondary,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isAssameseTranslit ? 'অসমীয়া ON' : 'অসমীয়া',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: isAssameseTranslit
                                        ? AppTheme.accentPurple
                                        : AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),

                        // Web Search Toggle Pill
                        InkWell(
                          onTap: onToggleWebSearch,
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: webSearch
                                  ? AppTheme.accentCyan.withValues(alpha: 0.15)
                                  : AppTheme.bgPill,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: webSearch
                                    ? AppTheme.accentCyan.withValues(alpha: 0.5)
                                    : AppTheme.borderColor,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.language_rounded,
                                  size: 11,
                                  color: webSearch
                                      ? AppTheme.accentCyan
                                      : AppTheme.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  webSearch ? 'Web ON' : 'Web',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: webSearch
                                        ? AppTheme.accentCyan
                                        : AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),

                        // Tools Pill
                        InkWell(
                          onTap: onOpenTools,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.bgPill,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.borderColor),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.dashboard_customize_rounded,
                                  size: 11,
                                  color: AppTheme.textSecondary,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  '31+ Tools',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Right Send Button
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: controller,
                      builder: (context, value, child) {
                        final canSend =
                            value.text.trim().isNotEmpty && !isLoading;

                        return Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            gradient: canSend
                                ? AppTheme.primaryGradient
                                : LinearGradient(
                                    colors: [
                                      Colors.white.withValues(alpha: 0.08),
                                      Colors.white.withValues(alpha: 0.04),
                                    ],
                                  ),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: isLoading
                                ? const SpinKitRing(
                                    color: Colors.white,
                                    size: 16,
                                    lineWidth: 2,
                                  )
                                : Icon(
                                    Icons.arrow_upward_rounded,
                                    size: 18,
                                    color: canSend
                                        ? Colors.white
                                        : AppTheme.textDim,
                                  ),
                            onPressed: canSend ? onSend : null,
                            tooltip: 'Send message',
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Bottom Disclaimer
          const Padding(
            padding: EdgeInsets.only(top: 6.0),
            child: Text(
              'Axom AI can make mistakes. Please verify important information.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.5,
                color: AppTheme.textDim,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
