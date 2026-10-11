import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

class CompressPdfScreen extends StatefulWidget {
  const CompressPdfScreen({super.key});

  @override
  State<CompressPdfScreen> createState() => _CompressPdfScreenState();
}

class _CompressPdfScreenState extends State<CompressPdfScreen> {
  PlatformFile? _selectedPdf;
  String _compressionLevel = 'moderate'; // 'extreme', 'moderate', 'low'
  bool _isCompressing = false;
  Map<String, dynamic>? _result;
  String? _errorMessage;

  final List<Map<String, String>> _levels = [
    {
      'id': 'extreme',
      'title': 'Extreme Compression',
      'desc': 'Smallest file size (low image DPI)',
    },
    {
      'id': 'moderate',
      'title': 'Recommended (Standard)',
      'desc': 'Great balance between size & crisp quality',
    },
    {
      'id': 'low',
      'title': 'Low Compression',
      'desc': 'Highest image clarity with mild reduction',
    },
  ];

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

  Future<void> _compressPdf() async {
    if (_selectedPdf == null) return;

    setState(() {
      _isCompressing = true;
      _errorMessage = null;
      _result = null;
    });

    final res = await ApiService.executePdfTool(
      op: 'compress',
      files: [_selectedPdf!],
      level: _compressionLevel,
    );

    if (mounted) {
      setState(() {
        _isCompressing = false;
        if (res['success'] == true) {
          _result = res;
        } else {
          _errorMessage = res['error'] ?? 'PDF compression failed. Please try again.';
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
        title: Text('Compress PDF File', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary)),
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
                      color: AppTheme.accentBlue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.compress_rounded, color: AppTheme.accentBlue, size: 30),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Reduce PDF File Size', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary)),
                        const SizedBox(height: 4),
                        Text('Optimize and compress heavy PDF documents without losing readability or essential quality.', style: TextStyle(fontSize: 12.5, color: textSecondary, height: 1.35)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Pick Box
            InkWell(
              onTap: _isCompressing ? null : _pickPdf,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _selectedPdf != null ? AppTheme.accentBlue : borderCol,
                    width: _selectedPdf != null ? 1.5 : 1,
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
                      child: Icon(_selectedPdf != null ? Icons.check_circle_rounded : Icons.picture_as_pdf_rounded, color: AppTheme.accentBlue, size: 32),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _selectedPdf != null ? _selectedPdf!.name : 'Tap to Choose PDF Document',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _selectedPdf != null
                          ? '${(_selectedPdf!.size / (1024 * 1024)).toStringAsFixed(2)} MB • Ready to compress'
                          : 'Supports standard .pdf up to 40MB',
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Compression Level Selector
            Text('Select Compression Preset:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary)),
            const SizedBox(height: 10),
            Column(
              children: _levels.map((lvl) {
                final isSelected = _compressionLevel == lvl['id'];
                return InkWell(
                  onTap: () => setState(() => _compressionLevel = lvl['id']!),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.accentBlue.withValues(alpha: 0.12) : cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppTheme.accentBlue : borderCol,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                          color: isSelected ? AppTheme.accentBlue : textSecondary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(lvl['title']!, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: isSelected ? AppTheme.accentBlue : textPrimary)),
                              Text(lvl['desc']!, style: TextStyle(fontSize: 11.5, color: textSecondary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Action Button
            ElevatedButton(
              onPressed: (_selectedPdf != null && !_isCompressing) ? _compressPdf : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentBlue,
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
                        Text('Compressing PDF...', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    )
                  : const Text('Compress PDF Document', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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
            if (_result != null && _result!['success'] == true) ...[
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
                        Text('PDF Compressed Successfully!', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('Output: ${_result!["output_name"] ?? "compressed.pdf"}', style: TextStyle(fontSize: 13, color: textPrimary)),
                    const SizedBox(height: 4),
                    Text('New Size: ${_result!["file_size"] ?? "Optimized PDF"}', style: TextStyle(fontSize: 12, color: textSecondary)),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: const Text('Download Compressed PDF'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.successGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => _downloadFile(_result!['download_url']),
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
