import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/chat_message.dart';
import '../services/api_service.dart';
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
  bool _isExporting = false;
  String? _feedback;

  void _handleCopy() {
    Clipboard.setData(ClipboardData(text: widget.message.text));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Future<void> _handleExportDocx() async {
    setState(() => _isExporting = true);
    final res = await ApiService.exportChatDocx(
      title: 'Axom AI Chat Response',
      messages: [
        {'role': 'assistant', 'text': widget.message.text}
      ],
    );

    if (!mounted) return;
    setState(() => _isExporting = false);

    if (res['success'] == true && res['download_url'] != null) {
      final uri = Uri.parse(res['download_url']);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('📄 Exported Word DOCX successfully!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['error'] ?? 'Export failed.')),
      );
    }
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
                colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
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
                color: AppTheme.bgCard,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(5),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
                border: Border.all(
                  color: AppTheme.borderColor,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
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
                              color: AppTheme.accentPurple,
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
                        children: [
                          if (_isExporting)
                            const SpinKitRing(color: AppTheme.accentCyan, size: 14, lineWidth: 2)
                          else
                            IconButton(
                              icon: const Icon(Icons.download_rounded, size: 16, color: AppTheme.textMuted),
                              tooltip: 'Export to Word (.docx)',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: _handleExportDocx,
                            ),
                          const SizedBox(width: 8),
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
                        const Row(
                          children: [
                            Icon(Icons.search_rounded, size: 12, color: Color(0xFF94A3B8)),
                            SizedBox(width: 4),
                            Text(
                              'Grounded Web Sources:',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFCBD5E1),
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
                                  color: const Color(0xFF191D30),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.link_rounded, size: 11, color: AppTheme.accentCyan),
                                    const SizedBox(width: 4),
                                    Text(
                                      domain,
                                      style: const TextStyle(fontSize: 10.5, color: Color(0xFFE2E8F0)),
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

                  // Markdown Body
                  MarkdownBody(
                    data: msg.text,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet(
                      p: const TextStyle(
                        fontSize: 14.5,
                        height: 1.6,
                        color: Color(0xFFECECF1),
                      ),
                      h1: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, height: 1.4),
                      h2: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, height: 1.4),
                      h3: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white, height: 1.4),
                      strong: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                      em: const TextStyle(fontStyle: FontStyle.italic, color: Color(0xFFECECF1)),
                      code: const TextStyle(
                        backgroundColor: Color(0xFF1B1E30),
                        color: Color(0xFF38BDF8),
                        fontSize: 12.5,
                        fontFamily: 'monospace',
                      ),
                      codeblockDecoration: BoxDecoration(
                        color: const Color(0xFF121422),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      codeblockPadding: const EdgeInsets.all(12),
                      listBullet: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 14, fontWeight: FontWeight.bold),
                      a: const TextStyle(color: Color(0xFF60A5FA), decoration: TextDecoration.underline),
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
