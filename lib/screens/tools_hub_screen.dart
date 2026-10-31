import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'tools/voice_notes_generator_screen.dart';
import 'tools/word_to_pdf_screen.dart';
import 'tools/pdf_to_word_screen.dart';
import 'tools/image_to_pdf_screen.dart';
import 'tools/pdf_to_image_screen.dart';
import 'tools/image_format_converter_screen.dart';
import 'tools/compress_pdf_screen.dart';
import 'tools/image_compressor_screen.dart';
import 'tools/video_compressor_screen.dart';

class ToolsHubScreen extends StatelessWidget {
  final bool isRootTab;
  const ToolsHubScreen({super.key, this.isRootTab = false});

  static const List<Map<String, dynamic>> _noteTemplates = [
    {
      'id': 'study',
      'title': 'Study Notes',
      'description':
          'Chapter-wise structured notes, definitions, formulas, and high-yield exam revision points ⭐.',
      'icon': Icons.school_rounded,
      'color': Color(0xFF8B5CF6),
      'badge': 'POPULAR ⭐',
    },
    {
      'id': 'meeting',
      'title': 'Meeting Minutes',
      'description':
          'Meeting agenda, attendee decisions, key discussion points, and clear follow-up action items.',
      'icon': Icons.business_center_rounded,
      'color': Color(0xFF06B6D4),
      'badge': 'OFFICE & TEAMS',
    },
    {
      'id': 'ideas',
      'title': 'Brainstorm & Ideas',
      'description':
          'Unfiltered creative thoughts converted into organized, categorized, and actionable concepts.',
      'icon': Icons.lightbulb_rounded,
      'color': Color(0xFFF59E0B),
      'badge': 'CREATIVE',
    },
    {
      'id': 'summary',
      'title': 'Executive Summary',
      'description':
          'High-impact 5-point executive recap of long lectures, conversations, or voice recordings.',
      'icon': Icons.bolt_rounded,
      'color': Color(0xFF10B981),
      'badge': 'EXPRESS',
    },
  ];

  void _openVoiceNotes(BuildContext context, {String mode = 'study'}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VoiceNotesGeneratorScreen(initialMode: mode),
      ),
    );
  }

  void _openWordToPdf(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const WordToPdfScreen()),
    );
  }

  void _openPdfToWord(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PdfToWordScreen()),
    );
  }

  void _openImageToPdf(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ImageToPdfScreen()),
    );
  }

  void _openPdfToJpg(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PdfToImageScreen(initialFormat: 'jpg'),
      ),
    );
  }

  void _openPdfToPng(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PdfToImageScreen(initialFormat: 'png'),
      ),
    );
  }

  void _openImageFormatConverter(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ImageFormatConverterScreen(),
      ),
    );
  }

  void _openCompressPdf(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CompressPdfScreen()),
    );
  }

  void _openImageCompressor(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ImageCompressorScreen()),
    );
  }

  void _openVideoCompressor(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const VideoCompressorScreen()),
    );
  }

  // ─── MODAL BOTTOM SHEET: SHOW THE 4 STYLE CARDS ON CLICK ─────────────
  void _showStyleSelectorModal(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? AppTheme.bgCard : Colors.white;
    final itemBg = isDark ? const Color(0xFF13172E) : const Color(0xFFF8FAFC);
    final borderCol = isDark ? AppTheme.borderColor : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? AppTheme.textPrimary : const Color(0xFF0F172A);
    final textSecondary = isDark
        ? AppTheme.textSecondary
        : const Color(0xFF64748B);

    showModalBottomSheet(
      context: context,
      backgroundColor: sheetBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: borderCol.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Note Style',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Choose how you want your spoken audio formatted',
                          style: TextStyle(
                            fontSize: 12,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      color: textSecondary,
                      onPressed: () => Navigator.pop(modalContext),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ..._noteTemplates.map((template) {
                  final color = template['color'] as Color;
                  final badge = template['badge'] as String;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: itemBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderCol),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          Navigator.pop(modalContext);
                          _openVoiceNotes(
                            context,
                            mode: template['id'] as String,
                          );
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.all(13),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: color.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Icon(
                                  template['icon'] as IconData,
                                  color: color,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            template['title'] as String,
                                            style: TextStyle(
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.bold,
                                              color: textPrimary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: color.withValues(
                                              alpha: 0.12,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            badge,
                                            style: TextStyle(
                                              fontSize: 8.5,
                                              fontWeight: FontWeight.w800,
                                              color: color,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      template['description'] as String,
                                      style: TextStyle(
                                        fontSize: 12,
                                        height: 1.35,
                                        color: textSecondary,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 13,
                                color: textSecondary.withValues(alpha: 0.5),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgCol = isDark ? AppTheme.bgDark : const Color(0xFFF8FAFC);
    final cardBg = isDark ? AppTheme.bgCard : Colors.white;
    final borderCol = isDark ? AppTheme.borderColor : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? AppTheme.textPrimary : const Color(0xFF0F172A);
    final textSecondary = isDark
        ? AppTheme.textSecondary
        : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bgCol,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        leading: isRootTab
            ? null
            : IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
                onPressed: () => Navigator.pop(context),
              ),
        title: Text(
          'Axom AI Tools',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textPrimary,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: borderCol, height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ═════════════════════════════════════════════════════════════════
            // 1. FEATURED AI TOOLS SECTION
            // ═════════════════════════════════════════════════════════════════
            _buildSectionHeader('Featured AI Tools', 'PRO', const Color(0xFF10B981), textPrimary),
            const SizedBox(height: 12),

            _buildToolCard(
              context: context,
              title: 'Voice Notes Generator',
              subtitle: 'Speech to Structured Text & Notes',
              description: 'Dictate in real-time in Assamese, English, or Hindi. Auto-type, synthesize notes, and export to Word.',
              badge: 'PRO ⭐',
              icon: Icons.keyboard_voice_rounded,
              color: const Color(0xFF10B981),
              onTap: () => _showStyleSelectorModal(context),
              isDark: isDark,
              cardBg: cardBg,
              borderCol: borderCol,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),

            const SizedBox(height: 20),

            // ═════════════════════════════════════════════════════════════════
            // 2. PDF & DOCUMENT TOOLS SECTION
            // ═════════════════════════════════════════════════════════════════
            _buildSectionHeader('PDF & Document Tools', 'STUDY & OFFICE', const Color(0xFF6366F1), textPrimary),
            const SizedBox(height: 12),

            // Word to PDF
            _buildToolCard(
              context: context,
              title: 'Word to PDF Converter',
              subtitle: 'Lossless DOCX & DOC Conversion',
              description: 'Convert Word files (.docx, .doc, .rtf, .txt) into pristine PDF documents with fonts, tables, and layout preserved.',
              badge: 'HD PDF ⭐',
              icon: Icons.picture_as_pdf_rounded,
              color: const Color(0xFF6366F1),
              onTap: () => _openWordToPdf(context),
              isDark: isDark,
              cardBg: cardBg,
              borderCol: borderCol,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),

            // PDF to Word
            _buildToolCard(
              context: context,
              title: 'PDF to Word Converter',
              subtitle: 'Editable Microsoft Word (.DOCX)',
              description: 'Convert PDF files into fully editable Microsoft Word documents with tables, fonts, formatting, and layout preserved.',
              badge: 'DOCX ⭐',
              icon: Icons.description_rounded,
              color: const Color(0xFF2563EB),
              onTap: () => _openPdfToWord(context),
              isDark: isDark,
              cardBg: cardBg,
              borderCol: borderCol,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),

            // Image to PDF
            _buildToolCard(
              context: context,
              title: 'Image to PDF Converter',
              subtitle: 'Merge Photos into a Single PDF',
              description: 'Convert JPG, PNG, and WebP images into a clean, vector-aligned PDF with page reordering and custom margins.',
              badge: 'BATCH ⭐',
              icon: Icons.photo_library_rounded,
              color: const Color(0xFF8B5CF6),
              onTap: () => _openImageToPdf(context),
              isDark: isDark,
              cardBg: cardBg,
              borderCol: borderCol,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),

            // Compress PDF
            _buildToolCard(
              context: context,
              title: 'Compress PDF',
              subtitle: 'Reduce PDF Size up to 90%',
              description: 'Shrink large PDF documents while maintaining pristine text sharpness, fonts, and image clarity.',
              badge: 'OPTIMIZE ⭐',
              icon: Icons.compress_rounded,
              color: const Color(0xFFEC4899),
              onTap: () => _openCompressPdf(context),
              isDark: isDark,
              cardBg: cardBg,
              borderCol: borderCol,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),

            const SizedBox(height: 20),

            // ═════════════════════════════════════════════════════════════════
            // 3. MEDIA & CONVERSION TOOLS SECTION
            // ═════════════════════════════════════════════════════════════════
            _buildSectionHeader('Media & Conversion Tools', 'FAST & CRISP', const Color(0xFFF59E0B), textPrimary),
            const SizedBox(height: 12),

            // PDF to JPG
            _buildToolCard(
              context: context,
              title: 'PDF to JPG Converter',
              subtitle: 'Extract Pages as High-Res Images',
              description: 'Convert each page of your PDF into crisp, individual JPG images or download everything in a clean ZIP.',
              badge: 'HIGH-RES ⭐',
              icon: Icons.collections_rounded,
              color: const Color(0xFFF97316),
              onTap: () => _openPdfToJpg(context),
              isDark: isDark,
              cardBg: cardBg,
              borderCol: borderCol,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),

            // PDF to PNG
            _buildToolCard(
              context: context,
              title: 'PDF to PNG Converter',
              subtitle: 'Lossless Transparent PNG Extraction',
              description: 'Export PDF pages as crisp, lossless PNG graphics with ultra-sharp text and pixel-perfect raster quality.',
              badge: 'LOSSLESS ⭐',
              icon: Icons.image_outlined,
              color: const Color(0xFF06B6D4),
              onTap: () => _openPdfToPng(context),
              isDark: isDark,
              cardBg: cardBg,
              borderCol: borderCol,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),

            // Universal Image Format Converter
            _buildToolCard(
              context: context,
              title: 'Image Format Converter',
              subtitle: 'Universal Multi-Format Image Engine',
              description: 'Easily convert between JPG, PNG, WebP, PDF, BMP, and SVG with one click and instant download.',
              badge: 'UNIVERSAL ⭐',
              icon: Icons.transform_rounded,
              color: const Color(0xFF14B8A6),
              onTap: () => _openImageFormatConverter(context),
              isDark: isDark,
              cardBg: cardBg,
              borderCol: borderCol,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),

            // Image Compressor
            _buildToolCard(
              context: context,
              title: 'Image Compressor',
              subtitle: 'Lossless JPEG, PNG & WebP Reducer',
              description: 'Reduce photo file sizes by up to 85% with smart perceptual color optimization and batch processing.',
              badge: 'SMART ⭐',
              icon: Icons.photo_size_select_small_rounded,
              color: const Color(0xFFF59E0B),
              onTap: () => _openImageCompressor(context),
              isDark: isDark,
              cardBg: cardBg,
              borderCol: borderCol,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),

            // Video Compressor
            _buildToolCard(
              context: context,
              title: 'Video Compressor',
              subtitle: 'FFmpeg H.264 Hardware Acceleration',
              description: 'Compress MP4, MOV, and MKV videos for WhatsApp, Instagram Reels, and Email with zero audio sync delay.',
              badge: 'FFMPEG ⭐',
              icon: Icons.movie_creation_rounded,
              color: const Color(0xFF4F46E5),
              onTap: () => _openVideoCompressor(context),
              isDark: isDark,
              cardBg: cardBg,
              borderCol: borderCol,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),

            const SizedBox(height: 24),

            // ═════════════════════════════════════════════════════════════════
            // PRO FEATURES INFO PILLS
            // ═════════════════════════════════════════════════════════════════
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF131D31)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderCol),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.verified_rounded,
                        size: 16,
                        color: Color(0xFF10B981),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Axom AI Core Engines',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildFeatureChip(
                        'Pure Assamese Orthography (ৰ/ৱ)',
                        isDark,
                      ),
                      _buildFeatureChip('100% Vector Layout Retention', isDark),
                      _buildFeatureChip('Lossless Fonts & Tables', isDark),
                      _buildFeatureChip('Zero Watermark PDFs', isDark),
                      _buildFeatureChip('Native Android SAF Storage', isDark),
                      _buildFeatureChip('Direct Cloud Download', isDark),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String badge, Color badgeColor, Color textColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 3,
          ),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            badge,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: badgeColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToolCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String description,
    required String badge,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
    required Color cardBg,
    required Color borderCol,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: color.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tool Icon Box
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: color.withValues(alpha: 0.35),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    icon,
                    color: color,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),

                // Title, Subtitle, Description
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2.5,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badge,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.45,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: textSecondary.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureChip(String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 12,
            color: Color(0xFF10B981),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : const Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }
}
