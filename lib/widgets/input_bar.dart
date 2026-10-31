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
    final textSecondary = isDark ? AppTheme.textSecondary : const Color(0xFF475569);
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
        border: Border(
          top: BorderSide(color: barBorder, width: 0.5),
        ),
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
                    ? AppTheme.accentEmerald.withOpacity(0.5)
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
                    // ChatGPT-Style Plus (+) Action Trigger Button
                    Container(
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
                      child: IconButton(
                        icon: Icon(
                          Icons.add_rounded,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          size: 20,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        onPressed: () => _showPlusActionMenu(context),
                        tooltip: 'Actions & AI Tools',
                      ),
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
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 14.5,
                          ),
                          decoration: InputDecoration(
                            hintText: listening
                                ? (languageLabel.contains('অসমীয়া') || languageLabel.contains('Assamese')
                                    ? 'শুনিয়ে আছো... অসমীয়াত কওক...'
                                    : 'Listening... speak now...')
                                : transcribing
                                    ? (languageLabel.contains('অসমীয়া') || languageLabel.contains('Assamese')
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
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: webSearch
                                  ? AppTheme.accentCyan.withValues(alpha: 0.15)
                                  : pillBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: webSearch
                                    ? AppTheme.accentCyan.withValues(alpha: 0.5)
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
                            PopupMenuItem(value: 'assamese', child: Text('Assamese')),
                            PopupMenuItem(value: 'english', child: Text('English')),
                          ],
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: pillBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: pillBorder),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.translate_rounded,
                                    size: 11, color: textSecondary),
                                const SizedBox(width: 4),
                                Text(
                                  languageLabel,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: textSecondary,
                                  ),
                                ),
                                Icon(Icons.arrow_drop_down_rounded,
                                    size: 14, color: textSecondary),
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
                                  color: Colors.redAccent.withValues(alpha: 0.35 + 0.4 * lv),
                                  width: 1 + 4 * lv),
                            )
                          : null,
                      decoration: BoxDecoration(
                        color: listening
                            ? Colors.redAccent.withValues(alpha: 0.2)
                            : pillBg,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: listening ? Colors.redAccent : pillBorder),
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: transcribing
                            ? SpinKitRing(
                                color: textSecondary, size: 16, lineWidth: 2)
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
                            (value.text.trim().isNotEmpty || hasAttachment) && !isLoading;

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

  void _showPlusActionMenu(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgCard = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSub = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: bgCard,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Grab handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Options & Tools',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.accentEmerald.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'AI ASSISTANT',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.accentEmerald,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 1. Photos & Documents / OCR
              _buildPlusMenuItem(
                isDark: isDark,
                icon: Icons.image_rounded,
                iconColor: const Color(0xFF8B5CF6),
                iconBg: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                title: 'Photos & Documents',
                subtitle: 'Upload images, take photo or extract text via OCR',
                onTap: () {
                  Navigator.pop(ctx);
                  onPickAttachment();
                },
              ),
              const SizedBox(height: 10),

              // 2. Web Search Toggle
              _buildPlusMenuItem(
                isDark: isDark,
                icon: Icons.language_rounded,
                iconColor: const Color(0xFF06B6D4),
                iconBg: const Color(0xFF06B6D4).withValues(alpha: 0.15),
                title: 'Web Search',
                subtitle: webSearch
                    ? 'Active • Real-time live web grounding ON'
                    : 'Disabled • Tap to search the live web',
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: webSearch
                        ? AppTheme.accentCyan.withValues(alpha: 0.2)
                        : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: webSearch ? AppTheme.accentCyan : borderColor,
                    ),
                  ),
                  child: Text(
                    webSearch ? 'ON' : 'OFF',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: webSearch ? AppTheme.accentCyan : textSub,
                    ),
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  onToggleWebSearch();
                },
              ),
              const SizedBox(height: 10),

              // 3. AI Tools Hub
              _buildPlusMenuItem(
                isDark: isDark,
                icon: Icons.grid_view_rounded,
                iconColor: const Color(0xFF10B981),
                iconBg: const Color(0xFF10B981).withValues(alpha: 0.15),
                title: 'AI Tools Hub',
                subtitle: 'Explore 16+ smart tools (Voice Notes, PDF, Video, Image)',
                trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: textSub),
                onTap: () {
                  Navigator.pop(ctx);
                  onOpenTools();
                },
              ),
              const SizedBox(height: 10),

              // 4. Voice Notes Generator
              _buildPlusMenuItem(
                isDark: isDark,
                icon: Icons.keyboard_voice_rounded,
                iconColor: const Color(0xFFF43F5E),
                iconBg: const Color(0xFFF43F5E).withValues(alpha: 0.15),
                title: 'Voice Notes Generator',
                subtitle: 'Real-time Assamese & multi-language voice dictation',
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF43F5E).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'NEW ⭐',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFF43F5E),
                    ),
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (c) => const VoiceNotesGeneratorScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlusMenuItem({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.6) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? const Color(0xFF334155).withValues(alpha: 0.6) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}
