import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

class ImageCompressScreen extends StatefulWidget {
  const ImageCompressScreen({super.key});

  @override
  State<ImageCompressScreen> createState() => _ImageCompressScreenState();
}

class _ImageCompressScreenState extends State<ImageCompressScreen> {
  PlatformFile? _selectedImage;
  double _quality = 75;
  String _targetFormat = 'jpg';
  bool _isCompressing = false;
  FileConversionResult? _result;
  String? _errorMessage;

  Future<void> _pickImage() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'bmp', 'tiff'],
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

  Future<void> _compressImage() async {
    if (_selectedImage == null) return;

    setState(() {
      _isCompressing = true;
      _errorMessage = null;
      _result = null;
    });

    final res = await ApiService.convertFile(
      files: [_selectedImage!],
      target: _targetFormat,
    );

    if (mounted) {
      setState(() {
        _isCompressing = false;
        if (res.success) {
          _result = res;
        } else {
          _errorMessage = res.error ?? 'Failed to compress image.';
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
        title: Text('Image Compressor', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary)),
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
                      : [const Color(0xFFFFFBEB), const Color(0xFFFEF3C7)],
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
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.photo_size_select_small_rounded, color: Colors.amber, size: 30),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Shrink & Optimize Images', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary)),
                        const SizedBox(height: 4),
                        Text('Reduce image KB / MB size up to 85% with intelligent compression and quality control.', style: TextStyle(fontSize: 12.5, color: textSecondary, height: 1.35)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Pick Box
            InkWell(
              onTap: _isCompressing ? null : _pickImage,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _selectedImage != null ? Colors.amber : borderCol,
                    width: _selectedImage != null ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(_selectedImage != null ? Icons.check_circle_rounded : Icons.add_photo_alternate_rounded, color: Colors.amber, size: 32),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _selectedImage != null ? _selectedImage!.name : 'Tap to Choose Photo to Compress',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _selectedImage != null
                          ? '${(_selectedImage!.size / 1024).toStringAsFixed(1)} KB • Ready to optimize'
                          : 'Supports JPG, PNG, WEBP up to 25MB',
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Quality Slider Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderCol),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Compression Level: ${_quality.round()}% Quality', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: textPrimary)),
                      Text('${100 - _quality.round()}% Reduction', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.accentEmerald)),
                    ],
                  ),
                  Slider(
                    value: _quality,
                    min: 20,
                    max: 95,
                    divisions: 15,
                    activeColor: Colors.amber.shade700,
                    label: '${_quality.round()}%',
                    onChanged: (v) => setState(() => _quality = v),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Max Compression (Smallest KB)', style: TextStyle(fontSize: 11, color: textSecondary)),
                      Text('Crisp Detail (Best Visuals)', style: TextStyle(fontSize: 11, color: textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Compress Button
            ElevatedButton(
              onPressed: (_selectedImage != null && !_isCompressing) ? _compressImage : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isCompressing
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SpinKitRing(color: Colors.white, size: 20, lineWidth: 2),
                        SizedBox(width: 12),
                        Text('Compressing Photo...', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    )
                  : const Text('Compress Image Now', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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
                        Text('Image Compressed Successfully!', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('Output: ${_result!.outputName ?? "compressed.jpg"}', style: TextStyle(fontSize: 13, color: textPrimary)),
                    const SizedBox(height: 4),
                    Text('New Size: ${_result!.fileSize ?? "Optimized"}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.successGreen)),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: const Text('Download Compressed Image'),
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
