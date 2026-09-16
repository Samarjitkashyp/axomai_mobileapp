import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ToolItem {
  final String title;
  final String description;
  final IconData icon;
  final Color accentColor;
  final String badge;

  const ToolItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.accentColor,
    this.badge = '',
  });
}

class ToolsSheet extends StatelessWidget {
  const ToolsSheet({super.key});

  static const List<ToolItem> tools = [
    ToolItem(
      title: 'Word to PDF',
      description: 'Convert .docx, .doc, or .txt to formatted PDF documents',
      icon: Icons.picture_as_pdf_rounded,
      accentColor: AppTheme.accentPurple,
      badge: 'POPULAR',
    ),
    ToolItem(
      title: 'AI Image Generator',
      description: 'Generate and edit Assam-inspired art and imagery',
      icon: Icons.image_rounded,
      accentColor: AppTheme.accentPink,
      badge: 'AI',
    ),
    ToolItem(
      title: 'Background Remover',
      description: 'Remove backgrounds from photos instantly with AI',
      icon: Icons.layers_clear_rounded,
      accentColor: AppTheme.accentCyan,
      badge: 'NEW',
    ),
    ToolItem(
      title: 'AI Summarizer',
      description: 'Summarize long Assamese articles, essays, and news',
      icon: Icons.short_text_rounded,
      accentColor: AppTheme.accentBlue,
    ),
    ToolItem(
      title: 'QR Code Generator',
      description: 'Generate custom branded QR codes with colors and logos',
      icon: Icons.qr_code_2_rounded,
      accentColor: AppTheme.successGreen,
    ),
    ToolItem(
      title: 'Meme Generator',
      description: 'Create viral Assamese and trending memes in seconds',
      icon: Icons.mood_rounded,
      accentColor: Colors.amber,
    ),
    ToolItem(
      title: 'Screenshot to Code',
      description: 'Convert UI screenshots into clean HTML & Tailwind CSS',
      icon: Icons.code_rounded,
      accentColor: Colors.deepPurpleAccent,
      badge: 'PRO',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 14,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        border: Border(
          top: BorderSide(color: AppTheme.borderColor),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textDim,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.build_rounded,
                      size: 18, color: AppTheme.accentPurple),
                  SizedBox(width: 8),
                  Text(
                    'Axom AI Tools Suite',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded,
                    size: 18, color: AppTheme.textSecondary),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Creative & Document tools powered by Axom AI',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 14),

          // Tools Grid / List
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: tools.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final tool = tools[index];
                return InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Launching ${tool.title}...'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.bgPill,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: tool.accentColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: tool.accentColor.withValues(alpha: 0.3),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Icon(tool.icon,
                              color: tool.accentColor, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    tool.title,
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  if (tool.badge.isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: tool.accentColor
                                            .withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        tool.badge,
                                        style: TextStyle(
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.bold,
                                          color: tool.accentColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                tool.description,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded,
                            size: 13, color: AppTheme.textMuted),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
