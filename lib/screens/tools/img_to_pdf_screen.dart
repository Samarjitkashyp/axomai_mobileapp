import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

class ImgToPdfScreen extends StatefulWidget {
  const ImgToPdfScreen({super.key});

  @override
  State<ImgToPdfScreen> createState() => _ImgToPdfScreenState();
}

class _ImgToPdfScreenState extends State<ImgToPdfScreen> {
  List<PlatformFile> _selectedImages = [];
  bool _isConverting = false;
  FileConversionResult? _result;
  String? _errorMessage;

  Future<void> _pickImages() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'bmp', 'tiff'],
        allowMultiple: true,
        withData: true,
      );
      if (res != null && res.files.isNotEmpty) {
        setState(() {
          _selectedImages = [..._selectedImages, ...res.files];
          _result = null;
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() => _errorMessage = 'Failed to pick images: $e');
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _convertImagesToPdf() async {
    if (_selectedImages.isEmpty) return;

    setState(() {
      _isConverting = true;
      _errorMessage = null;
      _result = null;
    });

    final res = await ApiService.convertFile(
      files: _selectedImages,
      target: 'pdf',
    );

    if (mounted) {
      setState(() {
        _isConverting = false;
        if (res.success) {
          _result = res;
        } else {
          _errorMessage = res.error ?? 'Failed to convert images to PDF.';
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
        title: Text(
          'Image to PDF Converter',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
        ),
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
                      : [const Color(0xFFF0FDF4), const Color(0xFFDCFCE7)],
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
                      color: AppTheme.accentEmerald.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.photo_library_rounded, color: AppTheme.accentEmerald, size: 30),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Photos & Images to PDF',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Merge multiple JPG, PNG, WEBP photos into a single clean PDF album or document.',
                          style: TextStyle(fontSize: 12.5, color: textSecondary, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Pick box
            InkWell(
              onTap: _isConverting ? null : _pickImages,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _selectedImages.isNotEmpty ? AppTheme.accentEmerald : borderCol,
                    width: _selectedImages.isNotEmpty ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.accentEmerald.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add_photo_alternate_rounded, color: AppTheme.accentEmerald, size: 32),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _selectedImages.isNotEmpty
                          ? '${_selectedImages.length} Image${_selectedImages.length > 1 ? "s" : ""} Selected (Tap to add more)'
                          : 'Tap to Select Images (JPG, PNG, WEBP)',
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Supports multiple image selection up to 25MB total',
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Selected Images List Preview
            if (_selectedImages.isNotEmpty) ...[
              Text(
                'Selected Pages (${_selectedImages.length}):',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 90,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedImages.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (ctx, i) {
                    final f = _selectedImages[i];
                    return Stack(
                      children: [
                        Container(
                          width: 80,
                          height: 85,
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: borderCol),
                          ),
                          child: f.bytes != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.memory(f.bytes!, fit: BoxFit.cover),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.image_rounded, color: AppTheme.accentEmerald, size: 24),
                                    const SizedBox(height: 4),
                                    Text('Page ${i + 1}', style: TextStyle(fontSize: 10, color: textSecondary)),
                                  ],
                                ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: InkWell(
                            onTap: () => _removeImage(i),
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close_rounded, size: 12, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Action Button
            ElevatedButton(
              onPressed: (_selectedImages.isNotEmpty && !_isConverting) ? _convertImagesToPdf : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentEmerald,
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
                        Text('Compiling PDF...', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    )
                  : Text(
                      'Create PDF (${_selectedImages.length} Image${_selectedImages.length > 1 ? "s" : ""})',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
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
                    Expanded(
                      child: Text(_errorMessage!, style: const TextStyle(color: AppTheme.errorRed, fontSize: 13)),
                    ),
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
                        Text('PDF Generated Successfully!', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('Output: ${_result!.outputName ?? "images.pdf"}', style: TextStyle(fontSize: 13, color: textPrimary)),
                    const SizedBox(height: 4),
                    Text('Size: ${_result!.fileSize ?? "PDF Document"}', style: TextStyle(fontSize: 12, color: textSecondary)),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: const Text('Download PDF Document'),
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
