import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/chat_message.dart';
import '../services/voice_service.dart';
import '../theme/app_theme.dart';

class MessageBubble extends StatefulWidget {
  final ChatMessage message;
  final bool isStreaming;

  const MessageBubble({
    super.key,
    required this.message,
    this.isStreaming = false,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  bool _copied = false;
  String? _feedback;

  void _handleCopy() {
    Clipboard.setData(ClipboardData(text: widget.message.text));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  void _handleSpeak() {
    VoiceService.instance.speak(widget.message.id, widget.message.text, onError: (m) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    });
  }

  Future<void> _openSourceUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }


  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: widget.message.isUser
          ? _buildUserBubble()
          : _buildAssistantBubble(),
    );
  }

  Widget _buildUserBubble() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 14.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              decoration: BoxDecoration(
                color: const Color(0xFF23273A),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(5),
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.message.imagePath != null &&
                      File(widget.message.imagePath!).existsSync())
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GestureDetector(
                        onTap: () => showDialog(
                          context: context,
                          builder: (_) => Dialog(
                            backgroundColor: Colors.black,
                            insetPadding: const EdgeInsets.all(8),
                            child: InteractiveViewer(
                              child: Image.file(File(widget.message.imagePath!)),
                            ),
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(widget.message.imagePath!),
                            width: 220,
                            fit: BoxFit.cover,
                            cacheWidth: 440,
                          ),
                        ),
                      ),
                    ),
                  if (widget.message.fileName != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.picture_as_pdf_rounded,
                              size: 18, color: Colors.white70),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(widget.message.fileName!,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12.5)),
                          ),
                        ],
                      ),
                    ),
                  if (widget.message.text.isNotEmpty)
                    Text(
                      widget.message.text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        height: 1.5,
                        letterSpacing: 0.1,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF33384F),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
              ),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: Colors.white70,
              size: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssistantBubble() {
    final msg = widget.message;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardBg = isDark ? AppTheme.bgCard : Colors.white;
    final cardBorder = isDark ? AppTheme.borderColor : const Color(0xFFE2E8F0);
    final textBodyColor = isDark ? const Color(0xFFECECF1) : const Color(0xFF1E293B);
    final headingColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final sourceChipBg = isDark ? const Color(0xFF191D30) : const Color(0xFFF1F5F9);
    final sourceChipBorder = isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0);
    final sourceChipTextColor = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155);
    final codeBlockBg = isDark ? const Color(0xFF121422) : const Color(0xFFF8FAFC);
    final codeInlineBg = isDark ? const Color(0xFF1B1E30) : const Color(0xFFE2E8F0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 14.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI Icon Avatar
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF34D399), Color(0xFF059669)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 15,
            ),
          ),
          const SizedBox(width: 10),

          // Message Card Content
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(5),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
                border: Border.all(
                  color: cardBorder,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Meta Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            msg.model,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.accentEmerald,
                            ),
                          ),
                          if (msg.webSearch) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.accentCyan.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppTheme.accentCyan.withOpacity(0.4)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.language_rounded, size: 10, color: AppTheme.accentCyan),
                                  SizedBox(width: 3),
                                  Text(
                                    'Web Grounded',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.accentCyan,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ValueListenableBuilder<String?>(
                            valueListenable: VoiceService.instance.speakingId,
                            builder: (context, speaking, _) {
                              final on = speaking == widget.message.id;
                              return IconButton(
                                icon: Icon(
                                  on ? Icons.stop_circle_rounded : Icons.volume_up_rounded,
                                  size: 17,
                                  color: on ? AppTheme.accentEmerald : AppTheme.textMuted,
                                ),
                                tooltip: on ? 'Stop' : 'Listen',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: _handleSpeak,
                              );
                            },
                          ),
                          const SizedBox(width: 12),
                      IconButton(
                        icon: Icon(
                          _copied ? Icons.check_rounded : Icons.copy_rounded,
                          size: 15,
                          color: _copied ? AppTheme.successGreen : AppTheme.textMuted,
                        ),
                        tooltip: 'Copy response',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: _handleCopy,
                      ),
                        ],
                      ),
                    ],
                  ),

                  // Web Sources Chips
                  if (msg.sources.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.search_rounded, size: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            const SizedBox(width: 4),
                            Text(
                              'Grounded Web Sources:',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: msg.sources.map((src) {
                            String domain = src.title;
                            try {
                              domain = Uri.parse(src.uri).host.replaceFirst('www.', '');
                            } catch (_) {}
                            return InkWell(
                              onTap: () => _openSourceUrl(src.uri),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: sourceChipBg,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: sourceChipBorder),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.link_rounded, size: 11, color: AppTheme.accentCyan),
                                    const SizedBox(width: 4),
                                    Text(
                                      domain,
                                      style: TextStyle(fontSize: 10.5, color: sourceChipTextColor),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 10),

                  // Fast Markdown Body (Ultra-smooth 60/120 FPS rendering)
                  MarkdownBody(
                    data: msg.text,
                    selectable: false,
                    onTapLink: (text, href, title) {
                      if (href != null) _openSourceUrl(href);
                    },
                    styleSheet: MarkdownStyleSheet(
                      p: TextStyle(
                        fontSize: 14.5,
                        height: 1.55,
                        color: textBodyColor,
                      ),
                      h1: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: headingColor, height: 1.35),
                      h2: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: headingColor, height: 1.35),
                      h3: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: headingColor, height: 1.35),
                      strong: TextStyle(fontWeight: FontWeight.w700, color: headingColor),
                      em: TextStyle(fontStyle: FontStyle.italic, color: textBodyColor),
                      code: TextStyle(
                        backgroundColor: codeInlineBg,
                        color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                        fontSize: 12.5,
                        fontFamily: 'monospace',
                      ),
                      codeblockDecoration: BoxDecoration(
                        color: codeBlockBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: cardBorder),
                      ),
                      codeblockPadding: const EdgeInsets.all(12),
                      listBullet: TextStyle(color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569), fontSize: 14, fontWeight: FontWeight.bold),
                      a: const TextStyle(color: Color(0xFF2563EB), decoration: TextDecoration.underline),
                    ),
                  ),

                  // Bottom Feedback Row
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (_feedback != null)
                        Text(
                          _feedback == 'up' ? '👍 Helpful' : '👎 Thanks for feedback',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        )
                      else ...[
                        InkWell(
                          onTap: () => setState(() => _feedback = 'up'),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppTheme.borderColor),
                            ),
                            child: const Icon(Icons.thumb_up_alt_outlined, size: 12, color: AppTheme.textMuted),
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => setState(() => _feedback = 'down'),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppTheme.borderColor),
                            ),
                            child: const Icon(Icons.thumb_down_alt_outlined, size: 12, color: AppTheme.textMuted),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
