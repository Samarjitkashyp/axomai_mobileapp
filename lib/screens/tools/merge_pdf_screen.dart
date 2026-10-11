import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

class MergePdfScreen extends StatefulWidget {
  const MergePdfScreen({super.key});

  @override
  State<MergePdfScreen> createState() => _MergePdfScreenState();
}

class _MergePdfScreenState extends State<MergePdfScreen> {
  List<PlatformFile> _pdfFiles = [];
  bool _isMerging = false;
  Map<String, dynamic>? _result;
  String? _errorMessage;

  Future<void> _pickPdfs() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: true,
        withData: true,
      );
      if (res != null && res.files.isNotEmpty) {
        setState(() {
          _pdfFiles = [..._pdfFiles, ...res.files];
          _result = null;
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() => _errorMessage = 'Failed to pick PDFs: $e');
    }
  }

  void _removePdf(int index) {
    setState(() {
      _pdfFiles.removeAt(index);
    });
  }

  Future<void> _mergePdfs() async {
    if (_pdfFiles.length < 2) {
      setState(() => _errorMessage = 'Please select at least 2 PDF documents to merge.');
      return;
    }

    setState(() {
      _isMerging = true;
      _errorMessage = null;
      _result = null;
    });

    final res = await ApiService.executePdfTool(
      op: 'merge',
      files: _pdfFiles,
    );

    if (mounted) {
      setState(() {
        _isMerging = false;
        if (res['success'] == true) {
          _result = res;
        } else {
          _errorMessage = res['error'] ?? 'PDF merge failed. Please try again.';
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
        title: Text('Merge PDF Files', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary)),
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
                      : [const Color(0xFFF5F3FF), const Color(0xFFEDE9FE)],
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
                      color: AppTheme.accentPurple.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.call_merge_rounded, color: AppTheme.accentPurple, size: 30),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Combine Multiple PDFs', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary)),
                        const SizedBox(height: 4),
                        Text('Merge 2 or more PDF documents into a single unified file in your preferred order.', style: TextStyle(fontSize: 12.5, color: textSecondary, height: 1.35)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Pick Box
            InkWell(
              onTap: _isMerging ? null : _pickPdfs,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _pdfFiles.isNotEmpty ? AppTheme.accentPurple : borderCol,
                    width: _pdfFiles.isNotEmpty ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.accentPurple.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.note_add_rounded, color: AppTheme.accentPurple, size: 32),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _pdfFiles.isNotEmpty
                          ? '${_pdfFiles.length} PDF${_pdfFiles.length > 1 ? "s" : ""} Added (Tap to add more)'
                          : 'Tap to Select 2 or More PDFs to Merge',
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text('Select multiple PDF documents up to 40MB total', style: TextStyle(fontSize: 12, color: textSecondary)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // PDF Files List
            if (_pdfFiles.isNotEmpty) ...[
              Text('Files to Merge (${_pdfFiles.length}):', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary)),
              const SizedBox(height: 8),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _pdfFiles.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final f = _pdfFiles[i];
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderCol),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: AppTheme.accentPurple.withValues(alpha: 0.15),
                          child: Text('${i + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.accentPurple)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(f.name, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text('${(f.size / 1024).toStringAsFixed(1)} KB', style: TextStyle(fontSize: 11.5, color: textSecondary)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18, color: Colors.redAccent),
                          onPressed: () => _removePdf(i),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
            ],

            // Merge Action Button
            ElevatedButton(
              onPressed: (_pdfFiles.length >= 2 && !_isMerging) ? _mergePdfs : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isMerging
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SpinKitRing(color: Colors.white, size: 20, lineWidth: 2),
                        SizedBox(width: 12),
                        Text('Merging PDF Documents...', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    )
                  : Text('Merge ${_pdfFiles.length} PDF Documents', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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
                        Text('Merged Successfully!', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('Output: ${_result!["output_name"] ?? "merged.pdf"}', style: TextStyle(fontSize: 13, color: textPrimary)),
                    const SizedBox(height: 4),
                    Text('Size: ${_result!["file_size"] ?? "PDF"}', style: TextStyle(fontSize: 12, color: textSecondary)),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: const Text('Download Merged PDF'),
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
