import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

class PdfToWordScreen extends StatefulWidget {
  const PdfToWordScreen({super.key});

  @override
  State<PdfToWordScreen> createState() => _PdfToWordScreenState();
}

class _PdfToWordScreenState extends State<PdfToWordScreen> {
  PlatformFile? _selectedFile;
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
          _selectedFile = res.files.first;
          _result = null;
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() => _errorMessage = 'Failed to select PDF: $e');
    }
  }

  Future<void> _convertPdfToWord() async {
    if (_selectedFile == null) return;

    setState(() {
      _isConverting = true;
      _errorMessage = null;
      _result = null;
    });

    final res = await ApiService.convertFile(
      files: [_selectedFile!],
      target: 'docx',
    );

    if (mounted) {
      setState(() {
        _isConverting = false;
        if (res.success) {
          _result = res;
        } else {
          _errorMessage = res.error ?? 'Conversion failed. Please try again.';
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
          'PDF to Word Converter',
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
            // Hero Banner Card
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
                      color: AppTheme.accentBlue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.description_rounded, color: AppTheme.accentBlue, size: 30),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PDF to Editable Word (.docx)',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Convert scanned & digital PDF documents into editable Word files preserving formatting, tables & text.',
                          style: TextStyle(fontSize: 12.5, color: textSecondary, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Upload Box
            InkWell(
              onTap: _isConverting ? null : _pickPdf,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _selectedFile != null ? AppTheme.accentBlue : borderCol,
                    width: _selectedFile != null ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.accentBlue.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _selectedFile != null ? Icons.check_circle_rounded : Icons.cloud_upload_rounded,
                        color: AppTheme.accentBlue,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _selectedFile != null ? _selectedFile!.name : 'Tap to Choose PDF Document',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _selectedFile != null
                          ? '${(_selectedFile!.size / (1024 * 1024)).toStringAsFixed(2)} MB • Ready to convert'
                          : 'Supports standard .pdf up to 25MB',
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Convert Button
            ElevatedButton(
              onPressed: (_selectedFile != null && !_isConverting) ? _convertPdfToWord : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _isConverting
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SpinKitRing(color: Colors.white, size: 20, lineWidth: 2),
                        SizedBox(width: 12),
                        Text('Converting PDF to DOCX...', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    )
                  : const Text('Convert to Word (.docx)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),

            // Error Notice
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

            // Result Card
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
                        Text(
                          'Conversion Complete!',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('Output: ${_result!.outputName ?? "document.docx"}', style: TextStyle(fontSize: 13, color: textPrimary)),
                    const SizedBox(height: 4),
                    Text('Size: ${_result!.fileSize ?? "Word DOCX"}', style: TextStyle(fontSize: 12, color: textSecondary)),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: const Text('Download Word Document'),
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
