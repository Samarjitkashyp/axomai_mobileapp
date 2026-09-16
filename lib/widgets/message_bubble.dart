import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/chat_message.dart';
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

  Future<void> _openSourceUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.message.isUser) {
      return _buildUserBubble();
    } else {
      return _buildAssistantBubble();
    }
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
                color: const Color(0xFF23273A), // Clean ChatGPT style dark capsule
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
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                widget.message.text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14.5,
                  height: 1.5,
                  letterSpacing: 0.1,
                ),
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
            alignment: Alignment.center,
            child: const Icon(
              Icons.person_rounded,
              color: Color(0xFFE2E8F0),
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssistantBubble() {
    final msg = widget.message;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sleek AI Emblem Avatar
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),

          // Message Container
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(15.0),
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Meta Row: Model label, Web Search badge & Action buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            msg.model,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          if (msg.webSearch) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0284C7)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFF38BDF8)
                                      .withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.public_rounded,
                                      size: 11, color: Color(0xFF38BDF8)),
                                  SizedBox(width: 4),
                                  Text(
                                    'Web Search',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF38BDF8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (msg.fromDatabase) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: AppTheme.successGreen
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppTheme.successGreen
                                      .withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: const Text(
                                '📁 Database Match',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.successGreen,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      // Copy Button
                      InkWell(
                        onTap: _handleCopy,
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _copied ? Icons.check : Icons.copy_rounded,
                                size: 12,
                                color: _copied
                                    ? AppTheme.successGreen
                                    : AppTheme.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _copied ? 'Copied!' : 'Copy',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _copied
                                      ? AppTheme.successGreen
                                      : AppTheme.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // ChatGPT-style Web Search Sources Carousel / Chips
                  if (msg.webSearch && msg.sources.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.travel_explore_rounded,
                                size: 13, color: Color(0xFF94A3B8)),
                            const SizedBox(width: 6),
                            Text(
                              'Sources (${msg.sources.length})',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFCBD5E1),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 34,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: msg.sources.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, idx) {
                              final src = msg.sources[idx];
                              String domain = src.title;
                              try {
                                domain = Uri.parse(src.uri)
                                    .host
                                    .replaceFirst('www.', '');
                              } catch (_) {}
                              return InkWell(
                                onTap: () => _openSourceUrl(src.uri),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 9, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF191D30),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.08),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.link_rounded,
                                          size: 12, color: Color(0xFF94A3B8)),
                                      const SizedBox(width: 5),
                                      Text(
                                        domain,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFFE2E8F0),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Markdown Body with ChatGPT Neutral, Clean Typography (No Pink!)
                  MarkdownBody(
                    data: msg.text,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet(
                      p: const TextStyle(
                        fontSize: 14.5,
                        height: 1.6,
                        color: Color(0xFFECECF1), // Crisp, readable ChatGPT off-white
                      ),
                      h1: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.4,
                      ),
                      h2: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.4,
                      ),
                      h3: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.4,
                      ),
                      strong: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      em: const TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Color(0xFFECECF1),
                      ),
                      code: const TextStyle(
                        backgroundColor: Color(0xFF1B1E30),
                        color: Color(0xFFE2E8F0), // Clean neutral code text (Not pink)
                        fontSize: 12.5,
                        fontFamily: 'monospace',
                      ),
                      codeblockDecoration: BoxDecoration(
                        color: const Color(0xFF121422),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      codeblockPadding: const EdgeInsets.all(12),
                      listBullet: const TextStyle(
                        color: Color(0xFFCBD5E1), // Clean neutral bullet (Not pink)
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      blockquote: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontStyle: FontStyle.italic,
                        fontSize: 14,
                      ),
                      blockquoteDecoration: const BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: Color(0xFF64748B),
                            width: 3,
                          ),
                        ),
                      ),
                      a: const TextStyle(
                        color: Color(0xFF60A5FA), // Modern web link blue
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),

                  // Bottom Feedback Row
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (_feedback != null)
                        Text(
                          _feedback == 'up'
                              ? '👍 Helpful'
                              : '👎 Thanks for feedback',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textMuted,
                          ),
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
                            child: const Icon(Icons.thumb_up_alt_outlined,
                                size: 12, color: AppTheme.textMuted),
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
                            child: const Icon(Icons.thumb_down_alt_outlined,
                                size: 12, color: AppTheme.textMuted),
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
