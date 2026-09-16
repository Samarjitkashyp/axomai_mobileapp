import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'tools/background_remover_screen.dart';
import 'tools/image_generator_screen.dart';
import 'tools/meme_generator_screen.dart';
import 'tools/qr_generator_screen.dart';
import 'tools/summarizer_screen.dart';
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
    ToolCardData(
      id: 'word2pdf',
      title: 'Word to PDF',
      category: 'Document & PDF',
      description:
          'Convert .docx, .doc, and .txt files to formatted PDF documents with high fidelity.',
      icon: Icons.picture_as_pdf_rounded,
      accentColor: AppTheme.accentPurple,
      badge: 'POPULAR',
      screenBuilder: () => const WordToPdfScreen(),
    ),
    ToolCardData(
      id: 'imggen',
      title: 'AI Image Generator',
      category: 'AI Tools',
      description:
          'Generate and edit Assam-inspired art, cultural landscapes, and photorealistic imagery.',
      icon: Icons.image_rounded,
      accentColor: AppTheme.accentPink,
      badge: 'AI',
      screenBuilder: () => const ImageGeneratorScreen(),
    ),
    ToolCardData(
      id: 'bgremover',
      title: 'Background Remover',
      category: 'Creative Suite',
      description:
          'Remove photo backgrounds instantly with AI edge detection for products and portraits.',
      icon: Icons.layers_clear_rounded,
      accentColor: AppTheme.accentCyan,
      badge: 'NEW',
      screenBuilder: () => const BackgroundRemoverScreen(),
    ),
    ToolCardData(
      id: 'summarizer',
      title: 'AI Text Summarizer',
      category: 'AI Tools',
      description:
          'Condense long articles, essays, and news reports into structured Assamese bullet points.',
      icon: Icons.short_text_rounded,
      accentColor: AppTheme.accentBlue,
      screenBuilder: () => const SummarizerScreen(),
    ),
    ToolCardData(
      id: 'qrgen',
      title: 'QR Code Generator',
      category: 'Utilities',
      description:
          'Create high-resolution branded QR codes for URLs, contact cards, and Wi-Fi.',
      icon: Icons.qr_code_2_rounded,
      accentColor: AppTheme.successGreen,
      screenBuilder: () => const QrGeneratorScreen(),
    ),
    ToolCardData(
      id: 'memegen',
      title: 'Meme Generator',
      category: 'Creative Suite',
      description:
          'Craft viral trending memes with popular templates and Impact font overlays.',
      icon: Icons.mood_rounded,
      accentColor: Colors.amber,
      screenBuilder: () => const MemeGeneratorScreen(),
    ),
  ];

  static const List<String> _categories = [
    'All',
    'AI Tools',
    'Document & PDF',
    'Creative Suite',
    'Utilities',
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
        title: const Text(
          'Axom AI Tools Suite',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded,
                      size: 18, color: AppTheme.textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: const TextStyle(
                          fontSize: 13.5, color: AppTheme.textPrimary),
                      decoration: const InputDecoration(
                        hintText: 'Search creative & PDF tools...',
                        hintStyle:
                            TextStyle(color: AppTheme.textMuted, fontSize: 13),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                      child: const Icon(Icons.clear_rounded,
                          size: 16, color: AppTheme.textMuted),
                    ),
                ],
              ),
            ),
          ),

          // Horizontal Category Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
            child: Row(
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    selected: isSelected,
                    label: Text(
                      cat,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : AppTheme.textSecondary,
                      ),
                    ),
                    backgroundColor: AppTheme.bgCard,
                    selectedColor: AppTheme.accentPurple,
                    checkmarkColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected
                            ? AppTheme.accentPurple
                            : AppTheme.borderColor,
                      ),
                    ),
                    onSelected: (_) =>
                        setState(() => _selectedCategory = cat),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 6),

          // Tools List / Cards
          Expanded(
            child: filteredTools.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search_off_rounded,
                            size: 44, color: AppTheme.textMuted),
                        const SizedBox(height: 10),
                        Text(
                          'No tools found for "$_searchQuery"',
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16.0, 10.0, 16.0, 100.0),
                    itemCount: filteredTools.length,
                    itemBuilder: (context, index) {
                      final tool = filteredTools[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.bgCard,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.borderColor),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => tool.screenBuilder(),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Tool Icon
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: tool.accentColor
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: tool.accentColor
                                          .withValues(alpha: 0.3),
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(tool.icon,
                                      color: tool.accentColor, size: 22),
                                ),
                                const SizedBox(width: 14),

                                // Details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            tool.title,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: AppTheme.textPrimary,
                                            ),
                                          ),
                                          if (tool.badge.isNotEmpty) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 1.5),
                                              decoration: BoxDecoration(
                                                color: tool.accentColor
                                                    .withValues(alpha: 0.2),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                tool.badge,
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  color: tool.accentColor,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        tool.description,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          height: 1.45,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 14,
                                  color: AppTheme.textMuted,
                                ),
                              ],
                            ),
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
