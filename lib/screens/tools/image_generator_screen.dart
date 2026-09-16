import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../../theme/app_theme.dart';

class ImageGeneratorScreen extends StatefulWidget {
  const ImageGeneratorScreen({super.key});

  @override
  State<ImageGeneratorScreen> createState() => _ImageGeneratorScreenState();
}

class _ImageGeneratorScreenState extends State<ImageGeneratorScreen> {
  final TextEditingController _promptController = TextEditingController();
  String _aspectRatio = '1:1';
  String _quality = 'normal';
  bool _isGenerating = false;
  String? _generatedImageUrl;

  static const List<String> _promptSuggestions = [
    'Traditional Bihu dancers in Assam tea garden at golden hour',
    'Majuli island satra architecture with serene Brahmaputra river',
    'One-horned rhinoceros in Kaziranga grassland foggy sunrise',
    'Futuristic Guwahati smart city with cybernetic flyovers and neon lights',
  ];

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _handleGenerate() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) return;

    setState(() {
      _isGenerating = true;
      _generatedImageUrl = null;
    });

    await Future.delayed(const Duration(milliseconds: 2500));

    if (!mounted) return;

    setState(() {
      _isGenerating = false;
      // High quality curated demo result
      _generatedImageUrl =
          'https://images.unsplash.com/photo-1596401057633-54a8fe8ef647?q=80&w=800&auto=format&fit=crop';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgMain,
      appBar: AppBar(
        backgroundColor: AppTheme.bgMain,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'AI Image Generator',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Prompt Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Image Prompt',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _promptController,
                    maxLines: 3,
                    style: const TextStyle(
                        fontSize: 14, color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                      hintText:
                          'Describe what you want to create in English or Assamese...',
                      hintStyle:
                          TextStyle(color: AppTheme.textMuted, fontSize: 13),
                      border: InputBorder.none,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Aspect ratio & Quality selector row
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildPill('1:1', _aspectRatio == '1:1', () {
                        setState(() => _aspectRatio = '1:1');
                      }),
                      _buildPill('16:9', _aspectRatio == '16:9', () {
                        setState(() => _aspectRatio = '16:9');
                      }),
                      _buildPill('9:16', _aspectRatio == '9:16', () {
                        setState(() => _aspectRatio = '9:16');
                      }),
                      const SizedBox(width: 8),
                      _buildPill('Normal (Flash)', _quality == 'normal', () {
                        setState(() => _quality = 'normal');
                      }, color: AppTheme.accentCyan),
                      _buildPill('Extreme (Pro)', _quality == 'extreme', () {
                        setState(() => _quality = 'extreme');
                      }, color: AppTheme.accentPink),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Prompt Suggestions
            const Text(
              'Suggestions',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMuted),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _promptSuggestions.map((suggestion) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ActionChip(
                      backgroundColor: AppTheme.bgPill,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: AppTheme.borderColor),
                      ),
                      label: Text(
                        suggestion.length > 34
                            ? '${suggestion.substring(0, 34)}...'
                            : suggestion,
                        style: const TextStyle(
                            fontSize: 11.5, color: AppTheme.textSecondary),
                      ),
                      onPressed: () {
                        _promptController.text = suggestion;
                      },
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 20),

            // Generate Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentPink,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isGenerating ? null : _handleGenerate,
              child: _isGenerating
                  ? const SpinKitRing(
                      color: Colors.white, size: 18, lineWidth: 2)
                  : const Text(
                      'Generate Artwork',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
            ),

            const SizedBox(height: 24),

            // Result Display
            if (_generatedImageUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: AspectRatio(
                  aspectRatio: _aspectRatio == '16:9'
                      ? 16 / 9
                      : (_aspectRatio == '9:16' ? 9 / 16 : 1),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        _generatedImageUrl!,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            color: AppTheme.bgCard,
                            alignment: Alignment.center,
                            child: const SpinKitDoubleBounce(
                                color: AppTheme.accentPink, size: 30),
                          );
                        },
                      ),
                      Positioned(
                        bottom: 12,
                        right: 12,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black.withValues(alpha: 0.7),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.download_rounded, size: 16),
                          label: const Text('Save to Gallery',
                              style: TextStyle(fontSize: 12)),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Saved image to photo album!'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPill(String label, bool isSelected, VoidCallback onTap,
      {Color color = AppTheme.accentPurple}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.2) : AppTheme.bgPill,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : AppTheme.borderColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? color : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
