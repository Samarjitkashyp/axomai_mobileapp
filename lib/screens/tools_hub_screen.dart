import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'tools/ai_notes_generator_screen.dart';
import 'tools/background_remover_screen.dart';
import 'tools/diagram_generator_screen.dart';
import 'tools/file_converter_screen.dart';
import 'tools/image_generator_screen.dart';
import 'tools/meme_generator_screen.dart';
import 'tools/qr_generator_screen.dart';
import 'tools/screenshot_to_code_screen.dart';
import 'tools/stock_media_screen.dart';
import 'tools/summarizer_screen.dart';
import 'tools/video_tools_screen.dart';
import 'tools/word_to_pdf_screen.dart';

class ToolCardData {
  final String id;
  final String title;
  final String category;
  final String description;
  final IconData icon;
  final Color accentColor;
  final String badge;
  final Widget Function() screenBuilder;

  const ToolCardData({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.icon,
    required this.accentColor,
    this.badge = '',
    required this.screenBuilder,
  });
}

class ToolsHubScreen extends StatefulWidget {
  final bool isRootTab;
  const ToolsHubScreen({super.key, this.isRootTab = false});

  @override
  State<ToolsHubScreen> createState() => _ToolsHubScreenState();
}

class _ToolsHubScreenState extends State<ToolsHubScreen> {
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  static final List<ToolCardData> _tools = [
    // ─── 1. AI Intelligence & Notes ─────────────────────────────────
    ToolCardData(
      id: 'ai-notes',
      title: 'AI Notes Generator',
      category: 'AI Study & Notes',
      description: 'Upload textbooks, PDFs or topics to synthesize exam-ready notes, flashcards, MCQs, and mindmaps.',
      icon: Icons.auto_stories_rounded,
      accentColor: AppTheme.accentPurple,
      badge: 'FEATURED ⭐',
      screenBuilder: () => const AiNotesGeneratorScreen(),
    ),
    ToolCardData(
      id: 'ai-diagram',
      title: 'AI Diagram Generator',
      category: 'AI Study & Notes',
      description: 'Generate flowcharts, sequence diagrams, mind maps, and system architectures from text prompts.',
      icon: Icons.account_tree_rounded,
      accentColor: AppTheme.accentCyan,
      badge: 'AI',
      screenBuilder: () => const DiagramGeneratorScreen(),
    ),
    ToolCardData(
      id: 'screenshot2code',
      title: 'Screenshot to Code',
      category: 'AI Study & Notes',
      description: 'Upload any app or website UI screenshot and extract clean HTML/Tailwind/Flutter code.',
      icon: Icons.code_rounded,
      accentColor: Colors.indigoAccent,
      badge: 'PRO',
      screenBuilder: () => const ScreenshotToCodeScreen(),
    ),
    ToolCardData(
      id: 'summarizer',
      title: 'AI Text Summarizer',
      category: 'AI Study & Notes',
      description: 'Condense long articles, essays, and news reports into structured Assamese & English bullet points.',
      icon: Icons.short_text_rounded,
      accentColor: AppTheme.accentBlue,
      screenBuilder: () => const SummarizerScreen(),
    ),

    // ─── 2. Document & PDF Suite ─────────────────────────────────────
    ToolCardData(
      id: 'word2pdf',
      title: 'Word to PDF',
      category: 'Document & PDF',
      description: 'Convert .docx, .doc, and .txt files to formatted PDF documents with high fidelity.',
      icon: Icons.picture_as_pdf_rounded,
      accentColor: AppTheme.accentPurple,
      badge: 'POPULAR',
      screenBuilder: () => const WordToPdfScreen(),
    ),
    ToolCardData(
      id: 'pdf2word',
      title: 'PDF to Word',
      category: 'Document & PDF',
      description: 'Convert .pdf files back to fully editable Microsoft Word .docx documents.',
      icon: Icons.description_rounded,
      accentColor: AppTheme.accentBlue,
      screenBuilder: () => const FileConverterScreen(initialTarget: 'pdf2word'),
    ),
    ToolCardData(
      id: 'img2pdf',
      title: 'Image to PDF',
      category: 'Document & PDF',
      description: 'Convert JPG, PNG, WebP images into a single clean printable PDF document.',
      icon: Icons.photo_library_rounded,
      accentColor: AppTheme.accentCyan,
      screenBuilder: () => const FileConverterScreen(initialTarget: 'img2pdf'),
    ),
    ToolCardData(
      id: 'pdf2img',
      title: 'PDF to JPG/PNG',
      category: 'Document & PDF',
      description: 'Extract high-resolution image pages from any PDF document.',
      icon: Icons.image_rounded,
      accentColor: Colors.amber,
      screenBuilder: () => const FileConverterScreen(initialTarget: 'pdf2jpg'),
    ),
    ToolCardData(
      id: 'excel2pdf',
      title: 'Excel to PDF',
      category: 'Document & PDF',
      description: 'Convert .xlsx, .xls spreadsheets and tables directly to PDF format.',
      icon: Icons.table_chart_rounded,
      accentColor: AppTheme.successGreen,
      screenBuilder: () => const FileConverterScreen(initialTarget: 'excel2pdf'),
    ),
    ToolCardData(
      id: 'ppt2pdf',
      title: 'PPT to PDF',
      category: 'Document & PDF',
      description: 'Convert .pptx, .ppt slide presentations into vector PDF documents.',
      icon: Icons.slideshow_rounded,
      accentColor: AppTheme.accentPink,
      screenBuilder: () => const FileConverterScreen(initialTarget: 'ppt2pdf'),
    ),

    // ─── 3. Creative & Design Suite ──────────────────────────────────
    ToolCardData(
      id: 'imggen',
      title: 'AI Image Generator',
      category: 'Creative Suite',
      description: 'Generate Assam-inspired art, cultural landscapes, and photorealistic imagery from prompts.',
      icon: Icons.image_rounded,
      accentColor: AppTheme.accentPink,
      badge: 'AI',
      screenBuilder: () => const ImageGeneratorScreen(),
    ),
    ToolCardData(
      id: 'bgremover',
      title: 'Background Remover',
      category: 'Creative Suite',
      description: 'Remove photo backgrounds instantly with AI edge detection for portraits & products.',
      icon: Icons.layers_clear_rounded,
      accentColor: AppTheme.accentCyan,
      badge: 'NEW',
      screenBuilder: () => const BackgroundRemoverScreen(),
    ),
    ToolCardData(
      id: 'stockphotos',
      title: 'Stock Image Finder',
      category: 'Creative Suite',
      description: 'Search and download millions of royalty-free, high-resolution stock photos.',
      icon: Icons.search_rounded,
      accentColor: Colors.tealAccent,
      screenBuilder: () => const StockMediaScreen(isVideoMode: false),
    ),
    ToolCardData(
      id: 'stockvideos',
      title: 'Stock Video Finder',
      category: 'Creative Suite',
      description: 'Search 4K & HD royalty-free stock video footage and b-rolls.',
      icon: Icons.videocam_rounded,
      accentColor: Colors.deepOrangeAccent,
      screenBuilder: () => const StockMediaScreen(isVideoMode: true),
    ),
    ToolCardData(
      id: 'memegen',
      title: 'Meme Generator',
      category: 'Creative Suite',
      description: 'Craft viral trending memes with popular templates and custom top/bottom text.',
      icon: Icons.mood_rounded,
      accentColor: Colors.amber,
      screenBuilder: () => const MemeGeneratorScreen(),
    ),

    // ─── 4. Media & Utilities ────────────────────────────────────────
    ToolCardData(
      id: 'videocompress',
      title: 'Video Compressor',
      category: 'Media & Utilities',
      description: 'Compress large MP4 and MOV videos by up to 80% on cloud FFmpeg servers without quality loss.',
      icon: Icons.video_file_rounded,
      accentColor: AppTheme.accentPurple,
      badge: 'GPU',
      screenBuilder: () => const VideoToolsScreen(initialIsDownloader: false),
    ),
    ToolCardData(
      id: 'videodownload',
      title: 'Video Downloader',
      category: 'Media & Utilities',
      description: 'Download public videos in high resolution from YouTube, Reels, and direct media URLs.',
      icon: Icons.download_for_offline_rounded,
      accentColor: AppTheme.accentCyan,
      screenBuilder: () => const VideoToolsScreen(initialIsDownloader: true),
    ),
    ToolCardData(
      id: 'qrgen',
      title: 'QR Code Generator',
      category: 'Media & Utilities',
      description: 'Create high-resolution branded QR codes for URLs, Wi-Fi, and contact cards.',
      icon: Icons.qr_code_2_rounded,
      accentColor: AppTheme.successGreen,
      screenBuilder: () => const QrGeneratorScreen(),
    ),
  ];

  static const List<String> _categories = [
    'All',
    'AI Study & Notes',
    'Document & PDF',
    'Creative Suite',
    'Media & Utilities',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredTools = _tools.where((tool) {
      final matchCat =
          _selectedCategory == 'All' || tool.category == _selectedCategory;
      final q = _searchQuery.trim().toLowerCase();
      final matchSearch = q.isEmpty ||
          tool.title.toLowerCase().contains(q) ||
          tool.description.toLowerCase().contains(q) ||
          tool.category.toLowerCase().contains(q);
      return matchCat && matchSearch;
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.bgMain,
      appBar: AppBar(
        backgroundColor: AppTheme.bgMain,
        elevation: 0,
        automaticallyImplyLeading: !widget.isRootTab,
        leading: widget.isRootTab
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: AppTheme.textPrimary, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.accentPurple.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.dashboard_customize_rounded,
                  color: AppTheme.accentPurple, size: 18),
            ),
            const SizedBox(width: 10),
            const Text(
              'Axom AI Tools Hub',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search & Filters Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            color: AppTheme.bgSurface,
            child: Column(
              children: [
                // Search Input
                TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search 31+ AI tools, PDF converters, and utilities...',
                    hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textSecondary, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18, color: AppTheme.textSecondary),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppTheme.bgMain,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),

                // Category Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categories.map((cat) {
                      final isSelected = _selectedCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(cat),
                          selected: isSelected,
                          selectedColor: AppTheme.accentPurple,
                          backgroundColor: AppTheme.bgMain,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : AppTheme.textSecondary,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          ),
                          onSelected: (_) => setState(() => _selectedCategory = cat),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Tools Grid
          Expanded(
            child: filteredTools.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded, size: 48, color: AppTheme.textSecondary.withOpacity(0.5)),
                        const SizedBox(height: 12),
                        Text('No tools matching "$_searchQuery"', style: const TextStyle(color: AppTheme.textSecondary)),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.88,
                    ),
                    itemCount: filteredTools.length,
                    itemBuilder: (context, idx) {
                      final tool = filteredTools[idx];
                      return _buildToolCard(tool);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolCard(ToolCardData tool) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => tool.screenBuilder()),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.bgSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.glassBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: tool.accentColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(tool.icon, color: tool.accentColor, size: 22),
                ),
                if (tool.badge.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: tool.accentColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: tool.accentColor.withOpacity(0.4)),
                    ),
                    child: Text(
                      tool.badge,
                      style: TextStyle(
                        color: tool.accentColor,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const Spacer(),
            Text(
              tool.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              tool.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
