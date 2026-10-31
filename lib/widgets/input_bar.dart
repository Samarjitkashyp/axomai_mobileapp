import 'package:flutter/material.dart';

import 'package:flutter_spinkit/flutter_spinkit.dart';

import '../services/voice_service.dart';

import '../theme/app_theme.dart';

import '../screens/tools/voice_notes_generator_screen.dart';

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

  final String languageLabel;

  final ValueChanged<String>? onLanguageChanged;

  final bool listening;

  final bool hasAttachment;

  final bool transcribing;

  final VoidCallback? onMic;

  const InputBar({
    super.key,

    this.languageLabel = 'অসমীয়া',

    this.onLanguageChanged,

    this.listening = false,

    this.hasAttachment = false,

    this.transcribing = false,

    this.onMic,

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final safeBottom = MediaQuery.of(context).padding.bottom;

    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    final effectiveBottom = isKeyboardOpen
        ? (safeBottom + 8)
        : ((bottomPadding ?? 8) + safeBottom);

    final barBg = isDark ? AppTheme.bgMain : Colors.white;

    final barBorder = isDark ? AppTheme.borderColor : const Color(0xFFE2E8F0);

    final cardBg = isDark ? AppTheme.bgInput : const Color(0xFFF8FAFC);

    final cardBorder = isDark ? AppTheme.borderColor : const Color(0xFFE2E8F0);

    final textPrimary = isDark ? AppTheme.textPrimary : const Color(0xFF0F172A);

    final textSecondary = isDark
        ? AppTheme.textSecondary
        : const Color(0xFF475569);

    final textMuted = isDark ? AppTheme.textMuted : const Color(0xFF94A3B8);

    final pillBg = isDark ? AppTheme.bgPill : const Color(0xFFF1F5F9);

    final pillBorder = isDark ? AppTheme.borderColor : const Color(0xFFE2E8F0);

    return Container(
      padding: EdgeInsets.only(
        left: 12,

        right: 12,

        top: 6,

        bottom: effectiveBottom,
      ),

      decoration: BoxDecoration(
        color: barBg.withValues(alpha: 0.95),

        border: Border(top: BorderSide(color: barBorder, width: 0.5)),
      ),

      child: Column(
        mainAxisSize: MainAxisSize.min,

        children: [
          // Input Card Container
          Container(
            decoration: BoxDecoration(
              color: cardBg,

              borderRadius: BorderRadius.circular(18),

              border: Border.all(
                color: isAssameseTranslit
                    ? AppTheme.accentEmerald.withValues(alpha: 0.5)
                    : cardBorder,

                width: 1,
              ),

              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),

                  blurRadius: 12,

                  offset: const Offset(0, 3),
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
                    // ChatGPT-Style Plus (+) Action Dropdown Menu
                    _buildPlusActionDropdown(
                      context,
                      isDark,
                      textPrimary,
                      textMuted,
                      cardBorder,
                    ),

                    const SizedBox(width: 8),

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

                          style: TextStyle(color: textPrimary, fontSize: 14.5),

                          decoration: InputDecoration(
                            hintText: listening
                                ? (languageLabel.contains('অসমীয়া') ||
                                          languageLabel.contains('Assamese')
                                      ? 'শুনিয়ে আছো... অসমীয়াত কওক...'
                                      : 'Listening... speak now...')
                                : transcribing
                                ? (languageLabel.contains('অসমীয়া') ||
                                          languageLabel.contains('Assamese')
                                      ? 'লিখি থকা হৈছে...'
                                      : 'Writing down what you said...')
                                : isAssameseTranslit
                                ? 'অসমীয়াত লিখক (e.g. axom)...'
                                : 'Message Axom AI...',

                            hintStyle: TextStyle(
                              color: listening ? Colors.redAccent : textMuted,

                              fontSize: 14.5,
                            ),

                            border: InputBorder.none,

                            isDense: true,

                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 8,
                            ),
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
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,

                        child: Row(
                          children: [
                            // Web Search Toggle Pill
                            InkWell(
                              onTap: onToggleWebSearch,

                              borderRadius: BorderRadius.circular(12),

                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),

                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),

                                decoration: BoxDecoration(
                                  color: webSearch
                                      ? AppTheme.accentCyan.withValues(
                                          alpha: 0.15,
                                        )
                                      : pillBg,

                                  borderRadius: BorderRadius.circular(12),

                                  border: Border.all(
                                    color: webSearch
                                        ? AppTheme.accentCyan.withValues(
                                            alpha: 0.5,
                                          )
                                        : pillBorder,
                                  ),
                                ),

                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.language_rounded,

                                      size: 11,

                                      color: webSearch
                                          ? AppTheme.accentCyan
                                          : textSecondary,
                                    ),

                                    const SizedBox(width: 4),

                                    Text(
                                      webSearch ? 'Web ON' : 'Web',

                                      style: TextStyle(
                                        fontSize: 10.5,

                                        fontWeight: FontWeight.w600,

                                        color: webSearch
                                            ? AppTheme.accentCyan
                                            : textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(width: 6),

                            // Reply language pill
                            PopupMenuButton<String>(
                              tooltip: 'Reply language',

                              padding: EdgeInsets.zero,

                              position: PopupMenuPosition.over,

                              onSelected: onLanguageChanged,

                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'assamese',
                                  child: Text('Assamese'),
                                ),

                                PopupMenuItem(
                                  value: 'english',
                                  child: Text('English'),
                                ),
                              ],

                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),

                                decoration: BoxDecoration(
                                  color: pillBg,

                                  borderRadius: BorderRadius.circular(12),

                                  border: Border.all(color: pillBorder),
                                ),

                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.translate_rounded,

                                      size: 11,
                                      color: textSecondary,
                                    ),

                                    const SizedBox(width: 4),

                                    Text(
                                      languageLabel,

                                      style: TextStyle(
                                        fontSize: 10.5,

                                        fontWeight: FontWeight.w600,

                                        color: textSecondary,
                                      ),
                                    ),

                                    Icon(
                                      Icons.arrow_drop_down_rounded,

                                      size: 14,
                                      color: textSecondary,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(width: 6),
                          ],
                        ),
                      ),
                    ),

                    // Mic (voice typing)
                    ValueListenableBuilder<double>(
                      valueListenable: VoiceService.instance.level,

                      builder: (context, lv, child) => Container(
                        width: 34,

                        height: 34,

                        margin: const EdgeInsets.only(right: 6),

                        foregroundDecoration: listening
                            ? BoxDecoration(
                                shape: BoxShape.circle,

                                border: Border.all(
                                  color: Colors.redAccent.withValues(
                                    alpha: 0.35 + 0.4 * lv,
                                  ),

                                  width: 1 + 4 * lv,
                                ),
                              )
                            : null,

                        decoration: BoxDecoration(
                          color: listening
                              ? Colors.redAccent.withValues(alpha: 0.2)
                              : pillBg,

                          shape: BoxShape.circle,

                          border: Border.all(
                            color: listening ? Colors.redAccent : pillBorder,
                          ),
                        ),

                        child: IconButton(
                          padding: EdgeInsets.zero,

                          icon: transcribing
                              ? SpinKitRing(
                                  color: textSecondary,
                                  size: 16,
                                  lineWidth: 2,
                                )
                              : Icon(
                                  listening
                                      ? Icons.stop_rounded
                                      : Icons.mic_rounded,

                                  size: 18,

                                  color: listening
                                      ? Colors.redAccent
                                      : textSecondary,
                                ),

                          onPressed: (isLoading || transcribing) ? null : onMic,

                          tooltip: listening ? 'Stop' : 'Voice typing',
                        ),
                      ),
                    ),

                    // Right Send Button
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: controller,

                      builder: (context, value, child) {
                        final canSend =
                            (value.text.trim().isNotEmpty || hasAttachment) &&
                            !isLoading;

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

              style: TextStyle(fontSize: 10.5, color: AppTheme.textDim),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlusActionDropdown(
    BuildContext context,
    bool isDark,
    Color textPrimary,
    Color textMuted,
    Color borderColor,
  ) {
    return Theme(
      data: Theme.of(context).copyWith(
        cardColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        popupMenuTheme: PopupMenuThemeData(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          elevation: 12,
          shadowColor: Colors.black.withValues(alpha: isDark ? 0.6 : 0.25),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
        ),
      ),
      child: PopupMenuButton<String>(
        tooltip: 'Actions & Tools',
        offset: const Offset(0, -225),
        position: PopupMenuPosition.over,
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 12,
        shadowColor: Colors.black.withValues(alpha: isDark ? 0.6 : 0.25),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        onSelected: (val) {
          if (val == 'attachment') {
            onPickAttachment();
          } else if (val == 'web') {
            onToggleWebSearch();
          } else if (val == 'tools') {
            onOpenTools();
          } else if (val == 'voice_notes') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (c) => const VoiceNotesGeneratorScreen(),
              ),
            );
          }
        },
        itemBuilder: (ctx) => [
          // 1. Photos & Documents
          PopupMenuItem<String>(
            value: 'attachment',
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.image_rounded,
                    color: Color(0xFF8B5CF6),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Photos & Docs',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const PopupMenuDivider(height: 1),

          // 2. Web Search Toggle
          PopupMenuItem<String>(
            value: 'web',
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF06B6D4).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.language_rounded,
                    color: Color(0xFF06B6D4),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Web Search',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2.5,
                  ),
                  decoration: BoxDecoration(
                    color: webSearch
                        ? AppTheme.accentCyan.withValues(alpha: 0.2)
                        : (isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFF1F5F9)),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: webSearch ? AppTheme.accentCyan : borderColor,
                      width: 0.6,
                    ),
                  ),
                  child: Text(
                    webSearch ? 'ON' : 'OFF',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: webSearch ? AppTheme.accentCyan : textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const PopupMenuDivider(height: 1),

          // 3. AI Tools Hub
          PopupMenuItem<String>(
            value: 'tools',
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.grid_view_rounded,
                    color: Color(0xFF10B981),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'AI Tools Hub',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 12,
                  color: textMuted,
                ),
              ],
            ),
          ),
          const PopupMenuDivider(height: 1),

          // 4. Voice Notes Generator
          PopupMenuItem<String>(
            value: 'voice_notes',
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF43F5E).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.keyboard_voice_rounded,
                    color: Color(0xFFF43F5E),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Voice Notes',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF43F5E).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'NEW',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFF43F5E),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
              width: 1,
            ),
          ),
          child: Center(
            child: Icon(
              Icons.add_rounded,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}
