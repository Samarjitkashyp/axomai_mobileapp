import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// Import dedicated screens for all 15 tools
import 'tools/word_to_pdf_screen.dart';
import 'tools/pdf_to_word_screen.dart';
import 'tools/img_to_pdf_screen.dart';
import 'tools/pdf_to_jpg_screen.dart';
import 'tools/pdf_to_png_screen.dart';
import 'tools/image_format_converter_screen.dart';
import 'tools/excel_to_pdf_screen.dart';
import 'tools/merge_pdf_screen.dart';
import 'tools/compress_pdf_screen.dart';
import 'tools/compress_video_screen.dart';
import 'tools/youtube_video_download_screen.dart';
import 'tools/video_download_screen.dart';
import 'tools/image_compress_screen.dart';
import 'tools/background_remover_screen.dart';
import 'tools/ai_notes_generator_screen.dart';

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
      category: 'AI Tools',
      description: 'Synthesize chapter-wise study notes, formulas, flashcards, MCQs, and mind maps from documents.',
      icon: Icons.auto_stories_rounded,
      accentColor: AppTheme.accentPurple,
      badge: 'POPULAR ⭐',
      screenBuilder: () => const AiNotesGeneratorScreen(),
    ),
    ToolCardData(
      id: 'background-remover',
      title: 'Background Remover',
      category: 'AI Tools',
      description: 'Remove background from portraits, products, and graphics with high-precision AI edge cutout.',
      icon: Icons.photo_filter_rounded,
      accentColor: AppTheme.accentCyan,
      badge: 'AI ENGINE',
      screenBuilder: () => const BackgroundRemoverScreen(),
    ),

    // ─── 2. Document & PDF Suite ─────────────────────────────────────
    ToolCardData(
      id: 'word-to-pdf',
      title: 'Word to PDF',
      category: 'PDF & Docs',
      description: 'Convert .docx, .doc, .rtf, and .txt files to high-fidelity PDF documents.',
      icon: Icons.picture_as_pdf_rounded,
      accentColor: AppTheme.accentPurple,
      badge: 'FAST',
      screenBuilder: () => const WordToPdfScreen(),
    ),
    ToolCardData(
      id: 'pdf-to-word',
      title: 'PDF to Word',
      category: 'PDF & Docs',
      description: 'Extract and convert PDF documents into fully editable Microsoft Word (.docx) files.',
      icon: Icons.description_rounded,
      accentColor: AppTheme.accentBlue,
      badge: 'EDITABLE',
      screenBuilder: () => const PdfToWordScreen(),
    ),
    ToolCardData(
      id: 'img-to-pdf',
      title: 'Img to PDF',
      category: 'PDF & Docs',
      description: 'Combine multiple JPG, PNG, and WebP images into a single organized PDF album.',
      icon: Icons.photo_library_rounded,
      accentColor: AppTheme.accentEmerald,
      screenBuilder: () => const ImgToPdfScreen(),
    ),
    ToolCardData(
      id: 'pdf-to-jpg',
      title: 'PDF to JPG',
      category: 'PDF & Docs',
      description: 'Extract PDF pages as high-resolution JPG images or download as a bundled ZIP.',
      icon: Icons.image_rounded,
      accentColor: Colors.amber,
      screenBuilder: () => const PdfToJpgScreen(),
    ),
    ToolCardData(
      id: 'pdf-to-png',
      title: 'PDF to PNG',
      category: 'PDF & Docs',
      description: 'Convert PDF pages into lossless PNG graphic images with transparency support.',
      icon: Icons.collections_rounded,
      accentColor: AppTheme.accentPink,
      screenBuilder: () => const PdfToPngScreen(),
    ),
    ToolCardData(
      id: 'excel-to-pdf',
      title: 'Excel to PDF',
      category: 'PDF & Docs',
      description: 'Convert .xlsx, .xls spreadsheets and CSV workbooks into clean printable PDF reports.',
      icon: Icons.table_chart_rounded,
      accentColor: AppTheme.successGreen,
      screenBuilder: () => const ExcelToPdfScreen(),
    ),
    ToolCardData(
      id: 'merge-pdf',
      title: 'Merge PDF',
      category: 'PDF & Docs',
      description: 'Combine 2 or more PDF documents into a single unified file in your chosen order.',
      icon: Icons.call_merge_rounded,
      accentColor: AppTheme.accentPurple,
      badge: 'MULTI',
      screenBuilder: () => const MergePdfScreen(),
    ),
    ToolCardData(
      id: 'compress-pdf',
      title: 'Compress PDF',
      category: 'PDF & Docs',
      description: 'Optimize and reduce PDF document file size with customizable compression levels.',
      icon: Icons.compress_rounded,
      accentColor: AppTheme.accentBlue,
      badge: 'OPTIMIZE',
      screenBuilder: () => const CompressPdfScreen(),
    ),

    // ─── 3. Images & Media ───────────────────────────────────────────
    ToolCardData(
      id: 'image-format-converter',
      title: 'Image Format Converter',
      category: 'Images',
      description: 'Convert images between PNG, JPG, WEBP, SVG, BMP, and TIFF with instant preview.',
      icon: Icons.transform_rounded,
      accentColor: AppTheme.accentCyan,
      screenBuilder: () => const ImageFormatConverterScreen(),
    ),
    ToolCardData(
      id: 'image-compress',
      title: 'Image Compress',
      category: 'Images',
      description: 'Reduce image file size up to 85% with interactive quality slider and live calculation.',
      icon: Icons.photo_size_select_small_rounded,
      accentColor: Colors.amber,
      badge: '85% SAVINGS',
      screenBuilder: () => const ImageCompressScreen(),
    ),

    // ─── 4. Video Tools ─────────────────────────────────────────────
    ToolCardData(
      id: 'compress-video',
      title: 'Compress Video',
      category: 'Video',
      description: 'Shrink large MP4, MOV, and MKV videos with background FFmpeg encoding.',
      icon: Icons.video_settings_rounded,
      accentColor: AppTheme.accentPink,
      badge: 'FFMPEG',
      screenBuilder: () => const CompressVideoScreen(),
    ),
    ToolCardData(
      id: 'youtube-video-download',
      title: 'YouTube Video Download',
      category: 'Video',
      description: 'Download YouTube videos, Shorts, and high-bitrate MP3 audio tracks directly.',
      icon: Icons.play_circle_filled_rounded,
      accentColor: Colors.red,
      badge: 'HOT 🔥',
      screenBuilder: () => const YoutubeVideoDownloadScreen(),
    ),
    ToolCardData(
      id: 'video-download',
      title: 'Video Download',
      category: 'Video',
      description: 'Universal online video saver for Instagram Reels, Twitter/X, FB, and direct MP4 URLs.',
      icon: Icons.cloud_download_rounded,
      accentColor: AppTheme.accentCyan,
      screenBuilder: () => const VideoDownloadScreen(),
    ),
  ];

  static const List<String> _categories = [
    'All',
    'PDF & Docs',
    'Images',
    'Video',
    'AI Tools',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ToolCardData> get _filteredTools {
    return _tools.where((tool) {
      final matchesCategory = _selectedCategory == 'All' || tool.category == _selectedCategory;
      final matchesQuery = _searchQuery.isEmpty ||
          tool.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          tool.description.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesQuery;
    }).toList();
  }

  void _openTool(ToolCardData tool) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => tool.screenBuilder()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgCol = isDark ? AppTheme.bgDark : const Color(0xFFF8FAFC);
    final cardBg = isDark ? AppTheme.bgCard : Colors.white;
    final borderCol = isDark ? AppTheme.borderColor : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? AppTheme.textPrimary : const Color(0xFF0F172A);
    final textSecondary = isDark ? AppTheme.textSecondary : const Color(0xFF64748B);

    final filtered = _filteredTools;

    return Scaffold(
      backgroundColor: bgCol,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        leading: widget.isRootTab
            ? null
            : IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
                onPressed: () => Navigator.pop(context),
              ),
        title: Text(
          'Axom AI Tools Hub',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: borderCol, height: 1),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          // ─── Header & Hero Banner ──────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF1E1B4B), const Color(0xFF0F172A)]
                        : [const Color(0xFFEEF2FF), const Color(0xFFE0E7FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderCol),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accentPurple.withValues(alpha: isDark ? 0.15 : 0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.accentPurple.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppTheme.accentPurple.withValues(alpha: 0.3)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.bolt_rounded, color: AppTheme.accentPurple, size: 14),
                              SizedBox(width: 4),
                              Text(
                                '15 SOVEREIGN UTILITIES',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.accentPurple,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'AI & Document Power Tools',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Fast, secure, and sovereign tools for PDF conversions, media compression, and AI study notes.',
                      style: TextStyle(fontSize: 13, color: textSecondary, height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ─── Real-Time Ajax Search Bar ──────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _searchQuery.isNotEmpty ? AppTheme.accentPurple : borderCol,
                    width: _searchQuery.isNotEmpty ? 1.5 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  style: TextStyle(color: textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search 15 tools (e.g., pdf, word, youtube, compress)...',
                    hintStyle: TextStyle(color: textSecondary, fontSize: 13.5),
                    prefixIcon: Icon(Icons.search_rounded, color: _searchQuery.isNotEmpty ? AppTheme.accentPurple : textSecondary, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear_rounded, color: textSecondary, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
            ),
          ),

          // ─── Category Filter Chips ──────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              height: 44,
              margin: const EdgeInsets.only(top: 8, bottom: 12),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, i) {
                  final cat = _categories[i];
                  final isSelected = _selectedCategory == cat;
                  final count = cat == 'All'
                      ? _tools.length
                      : _tools.where((t) => t.category == cat).length;

                  return InkWell(
                    onTap: () => setState(() => _selectedCategory = cat),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.accentPurple
                            : (isDark ? AppTheme.bgCard : Colors.white),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? AppTheme.accentPurple : borderCol,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            cat,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              color: isSelected ? Colors.white : textPrimary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white.withValues(alpha: 0.25)
                                  : (isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$count',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // ─── Tool Cards List / Grid ─────────────────────────────────
          if (filtered.isEmpty) ...[
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off_rounded, size: 56, color: textSecondary.withValues(alpha: 0.5)),
                      const SizedBox(height: 14),
                      Text(
                        'No tools found for "$_searchQuery"',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Try searching with a different keyword or reset filters.',
                        style: TextStyle(fontSize: 12.5, color: textSecondary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                            _selectedCategory = 'All';
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.accentPurple,
                          side: const BorderSide(color: AppTheme.accentPurple),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Reset Search & Filters'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ] else ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, index) {
                    final tool = filtered[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderCol),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: InkWell(
                        onTap: () => _openTool(tool),
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Icon Pill Container
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: tool.accentColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: tool.accentColor.withValues(alpha: 0.25),
                                  ),
                                ),
                                child: Icon(tool.icon, color: tool.accentColor, size: 24),
                              ),
                              const SizedBox(width: 14),

                              // Text details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            tool.title,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: textPrimary,
                                            ),
                                          ),
                                        ),
                                        if (tool.badge.isNotEmpty) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: tool.accentColor.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: tool.accentColor.withValues(alpha: 0.4)),
                                            ),
                                            child: Text(
                                              tool.badge,
                                              style: TextStyle(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w800,
                                                color: tool.accentColor,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      tool.description,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: textSecondary,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Chevron Action Arrow
                              Container(
                                margin: const EdgeInsets.only(top: 10),
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 13,
                                  color: textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: filtered.length,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
