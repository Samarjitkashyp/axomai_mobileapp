import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

class PdfToPngScreen extends StatefulWidget {
  const PdfToPngScreen({super.key});

  @override
  State<PdfToPngScreen> createState() => _PdfToPngScreenState();
}

class _PdfToPngScreenState extends State<PdfToPngScreen> {
  PlatformFile? _selectedPdf;
  bool _isConverting = false;
  FileConversionResult? _result;
  String? _errorMessage;

  Future<void> _pickPdf() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );
      if (res != null && res.files.isNotEmpty) {
        setState(() {
          _selectedPdf = res.files.first;
          _result = null;
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() => _errorMessage = 'Failed to select PDF: $e');
    }
  }

  Future<void> _convertPdfToPng() async {
    if (_selectedPdf == null) return;

    setState(() {
      _isConverting = true;
      _errorMessage = null;
      _result = null;
    });

    final res = await ApiService.convertFile(
      files: [_selectedPdf!],
      target: 'png',
    );

    if (mounted) {
      setState(() {
        _isConverting = false;
        if (res.success) {
          _result = res;
        } else {
          _errorMessage = res.error ?? 'Failed to convert PDF to PNG.';
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
        title: Text('PDF to PNG Converter', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary)),
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
                      : [const Color(0xFFFDF2F8), const Color(0xFFFCE7F3)],
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
                      color: AppTheme.accentPink.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.collections_rounded, color: AppTheme.accentPink, size: 30),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Lossless PNG Images from PDF', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary)),
                        const SizedBox(height: 4),
                        Text('Convert every PDF page into crisp, high-quality PNG graphic files with transparency support.', style: TextStyle(fontSize: 12.5, color: textSecondary, height: 1.35)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Pick Box
            InkWell(
              onTap: _isConverting ? null : _pickPdf,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _selectedPdf != null ? AppTheme.accentPink : borderCol,
                    width: _selectedPdf != null ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.accentPink.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(_selectedPdf != null ? Icons.check_circle_rounded : Icons.photo_size_select_actual_rounded, color: AppTheme.accentPink, size: 32),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _selectedPdf != null ? _selectedPdf!.name : 'Tap to Select PDF File',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _selectedPdf != null
                          ? '${(_selectedPdf!.size / (1024 * 1024)).toStringAsFixed(2)} MB • Ready to convert'
                          : 'Supports multi-page PDFs up to 25MB',
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Convert Button
            ElevatedButton(
              onPressed: (_selectedPdf != null && !_isConverting) ? _convertPdfToPng : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentPink,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isConverting
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SpinKitRing(color: Colors.white, size: 20, lineWidth: 2),
                        SizedBox(width: 12),
                        Text('Converting to PNG...', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    )
                  : const Text('Convert to PNG Images', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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
                        Text('PNG Images Generated!', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('Output: ${_result!.outputName ?? "images.zip"}', style: TextStyle(fontSize: 13, color: textPrimary)),
                    const SizedBox(height: 4),
                    Text('Format: ${_result!.fileSize ?? "PNG Images"}', style: TextStyle(fontSize: 12, color: textSecondary)),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: const Text('Download PNG Images'),
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
