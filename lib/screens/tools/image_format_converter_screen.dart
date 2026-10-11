import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

class ImageFormatConverterScreen extends StatefulWidget {
  const ImageFormatConverterScreen({super.key});

  @override
  State<ImageFormatConverterScreen> createState() => _ImageFormatConverterScreenState();
}

class _ImageFormatConverterScreenState extends State<ImageFormatConverterScreen> {
  PlatformFile? _selectedImage;
  String _targetFormat = 'png'; // 'png', 'jpg', 'webp', 'svg'
  bool _isConverting = false;
  FileConversionResult? _result;
  String? _errorMessage;

  final List<Map<String, dynamic>> _targetFormats = [
    {'ext': 'png', 'label': 'PNG (Lossless & Transparent)', 'icon': Icons.image_rounded, 'color': AppTheme.accentPink},
    {'ext': 'jpg', 'label': 'JPG (High Compression Photo)', 'icon': Icons.photo_rounded, 'color': Colors.amber},
    {'ext': 'webp', 'label': 'WEBP (Next-Gen Ultra Web)', 'icon': Icons.speed_rounded, 'color': AppTheme.accentCyan},
    {'ext': 'svg', 'label': 'SVG (Scalable Vector Graphic)', 'icon': Icons.polyline_rounded, 'color': AppTheme.accentPurple},
  ];

  Future<void> _pickImage() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'bmp', 'svg', 'tiff', 'gif', 'ico', 'avif', 'heic'],
        withData: true,
      );
      if (res != null && res.files.isNotEmpty) {
        setState(() {
          _selectedImage = res.files.first;
          _result = null;
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() => _errorMessage = 'Failed to select image: $e');
    }
  }

  Future<void> _convertImageFormat() async {
    if (_selectedImage == null) return;

    setState(() {
      _isConverting = true;
      _errorMessage = null;
      _result = null;
    });

    final res = await ApiService.convertFile(
      files: [_selectedImage!],
      target: _targetFormat,
    );

    if (mounted) {
      setState(() {
        _isConverting = false;
        if (res.success) {
          _result = res;
        } else {
          _errorMessage = res.error ?? 'Failed to convert image format.';
        }
      });
    }
  }

  Future<void> _downloadFile(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgCol = isDark ? AppTheme.bgDark : const Color(0xFFF8FAFC);
    final cardBg = isDark ? AppTheme.bgCard : Colors.white;
    final borderCol = isDark ? AppTheme.borderColor : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? AppTheme.textPrimary : const Color(0xFF0F172A);
    final textSecondary = isDark ? AppTheme.textSecondary : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bgCol,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Image Format Converter', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: borderCol, height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Banner
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                      : [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderCol),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.accentCyan.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.transform_rounded, color: AppTheme.accentCyan, size: 30),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Universal Image Converter', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary)),
                        const SizedBox(height: 4),
                        Text('Convert images between PNG, JPG, WEBP, SVG, BMP, TIFF and modern web formats.', style: TextStyle(fontSize: 12.5, color: textSecondary, height: 1.35)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Pick Box
            InkWell(
              onTap: _isConverting ? null : _pickImage,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _selectedImage != null ? AppTheme.accentCyan : borderCol,
                    width: _selectedImage != null ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.accentCyan.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(_selectedImage != null ? Icons.check_circle_rounded : Icons.add_photo_alternate_rounded, color: AppTheme.accentCyan, size: 32),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _selectedImage != null ? _selectedImage!.name : 'Tap to Choose Any Image',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _selectedImage != null
                          ? '${(_selectedImage!.size / (1024 * 1024)).toStringAsFixed(2)} MB • Ready to convert'
                          : 'Supports JPG, PNG, WEBP, SVG, BMP, TIFF up to 25MB',
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Target Format Picker
            Text('Convert Target Format:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary)),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.5,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: _targetFormats.length,
              itemBuilder: (ctx, i) {
                final fmt = _targetFormats[i];
                final isSelected = _targetFormat == fmt['ext'];
                final Color col = fmt['color'];
                return InkWell(
                  onTap: () => setState(() => _targetFormat = fmt['ext']),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? col.withValues(alpha: 0.15) : cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? col : borderCol,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(fmt['icon'], color: isSelected ? col : textSecondary, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(fmt['ext'].toString().toUpperCase(), style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: isSelected ? col : textPrimary)),
                              Text(fmt['label'].toString().split(' ')[0], style: TextStyle(fontSize: 10, color: textSecondary), overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            // Convert Button
            ElevatedButton(
              onPressed: (_selectedImage != null && !_isConverting) ? _convertImageFormat : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentCyan,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isConverting
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SpinKitRing(color: Colors.black, size: 20, lineWidth: 2),
                        SizedBox(width: 12),
                        Text('Converting Image...', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    )
                  : Text('Convert to ${_targetFormat.toUpperCase()}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),

            // Error
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.errorRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.errorRed.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppTheme.errorRed, size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_errorMessage!, style: const TextStyle(color: AppTheme.errorRed, fontSize: 13))),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Result
            if (_result != null && _result!.success) ...[
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.successGreen.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: AppTheme.successGreen, size: 22),
                        const SizedBox(width: 8),
                        Text('Image Converted Successfully!', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('Output: ${_result!.outputName ?? "image.$_targetFormat"}', style: TextStyle(fontSize: 13, color: textPrimary)),
                    const SizedBox(height: 4),
                    Text('Size: ${_result!.fileSize ?? _targetFormat.toUpperCase()}', style: TextStyle(fontSize: 12, color: textSecondary)),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: Text('Download ${_targetFormat.toUpperCase()} Image'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.successGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => _downloadFile(_result!.downloadUrl!),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
