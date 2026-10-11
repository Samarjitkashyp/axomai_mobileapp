import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

class CompressVideoScreen extends StatefulWidget {
  const CompressVideoScreen({super.key});

  @override
  State<CompressVideoScreen> createState() => _CompressVideoScreenState();
}

class _CompressVideoScreenState extends State<CompressVideoScreen> {
  PlatformFile? _selectedVideo;
  String _targetQuality = 'medium'; // 'low', 'medium', 'high'
  bool _isCompressing = false;
  String? _taskId;
  Timer? _statusTimer;
  Map<String, dynamic>? _compressResult;
  String? _compressError;

  final List<Map<String, String>> _qualities = [
    {'id': 'high', 'title': 'High Quality (720p/1080p)', 'desc': '~30-40% reduction, crisp detail'},
    {'id': 'medium', 'title': 'Balanced Quality (480p/720p)', 'desc': '~50-70% reduction (Recommended)'},
    {'id': 'low', 'title': 'Maximum Compression (360p)', 'desc': '~80-90% reduction, ultra compact'},
  ];

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.video,
        withData: true,
      );
      if (res != null && res.files.isNotEmpty) {
        setState(() {
          _selectedVideo = res.files.first;
          _compressResult = null;
          _compressError = null;
        });
      }
    } catch (e) {
      setState(() => _compressError = 'Failed to select video: $e');
    }
  }

  Future<void> _startCompression() async {
    if (_selectedVideo == null) return;

    setState(() {
      _isCompressing = true;
      _compressError = null;
      _compressResult = null;
    });

    final res = await ApiService.uploadVideoCompress(
      file: _selectedVideo!,
      targetQuality: _targetQuality,
    );

    if (res['success'] == true && res['task_id'] != null) {
      _taskId = res['task_id'];
      _pollCompressStatus();
    } else {
      if (mounted) {
        setState(() {
          _isCompressing = false;
          _compressError = res['error'] ?? 'Video upload failed.';
        });
      }
    }
  }

  void _pollCompressStatus() {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (_taskId == null) {
        timer.cancel();
        return;
      }
      final res = await ApiService.checkVideoCompressStatus(_taskId!);
      if (res['status'] == 'completed') {
        timer.cancel();
        if (mounted) {
          setState(() {
            _isCompressing = false;
            _compressResult = res;
          });
        }
      } else if (res['status'] == 'failed' || res['status'] == 'error') {
        timer.cancel();
        if (mounted) {
          setState(() {
            _isCompressing = false;
            _compressError = res['error'] ?? 'Video compression failed.';
          });
        }
      }
    });
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
        title: Text('Video Compressor', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary)),
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
                    child: const Icon(Icons.video_settings_rounded, color: AppTheme.accentPink, size: 30),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Compress MP4, MKV, MOV Videos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary)),
                        const SizedBox(height: 4),
                        Text('Shrink heavy video file size for faster sharing, messaging, and storage optimization.', style: TextStyle(fontSize: 12.5, color: textSecondary, height: 1.35)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Pick Box
            InkWell(
              onTap: _isCompressing ? null : _pickVideo,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _selectedVideo != null ? AppTheme.accentPink : borderCol,
                    width: _selectedVideo != null ? 1.5 : 1,
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
                      child: Icon(_selectedVideo != null ? Icons.check_circle_rounded : Icons.videocam_rounded, color: AppTheme.accentPink, size: 32),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _selectedVideo != null ? _selectedVideo!.name : 'Tap to Choose Video File',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _selectedVideo != null
                          ? '${(_selectedVideo!.size / (1024 * 1024)).toStringAsFixed(2)} MB • Ready to compress'
                          : 'Supports MP4, MOV, AVI, MKV up to 100MB',
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Quality Select
            Text('Select Target Quality:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary)),
            const SizedBox(height: 10),
            Column(
              children: _qualities.map((q) {
                final isSelected = _targetQuality == q['id'];
                return InkWell(
                  onTap: () => setState(() => _targetQuality = q['id']!),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.accentPink.withValues(alpha: 0.12) : cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppTheme.accentPink : borderCol,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                          color: isSelected ? AppTheme.accentPink : textSecondary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(q['title']!, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: isSelected ? AppTheme.accentPink : textPrimary)),
                              Text(q['desc']!, style: TextStyle(fontSize: 11.5, color: textSecondary)),
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

            // Button
            ElevatedButton(
              onPressed: (_selectedVideo != null && !_isCompressing) ? _startCompression : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentPink,
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
                        Text('Compressing Video (FFmpeg)...', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    )
                  : const Text('Compress Video', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),

            // Error
            if (_compressError != null) ...[
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
                    Expanded(child: Text(_compressError!, style: const TextStyle(color: AppTheme.errorRed, fontSize: 13))),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Result
            if (_compressResult != null) ...[
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
                        Text('Video Compressed Successfully!', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('Output: ${_compressResult!["filename"] ?? "compressed.mp4"}', style: TextStyle(fontSize: 13, color: textPrimary)),
                    const SizedBox(height: 4),
                    Text(
                      'Original: ${_compressResult!["original_size"] ?? "-"}  ➔  New: ${_compressResult!["compressed_size"] ?? "-"} (${_compressResult!["reduction_pct"] ?? "50"}% saved)',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.successGreen),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: const Text('Download Compressed Video'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.successGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => _downloadFile(_compressResult!['download_url']),
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
