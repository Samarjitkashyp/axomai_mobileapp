import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

class YoutubeVideoDownloadScreen extends StatefulWidget {
  const YoutubeVideoDownloadScreen({super.key});

  @override
  State<YoutubeVideoDownloadScreen> createState() => _YoutubeVideoDownloadScreenState();
}

class _YoutubeVideoDownloadScreenState extends State<YoutubeVideoDownloadScreen> {
  final TextEditingController _urlController = TextEditingController();
  bool _isFetching = false;
  Map<String, dynamic>? _videoInfo;
  String? _errorMessage;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _fetchYoutubeInfo() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() => _errorMessage = 'Please paste a valid YouTube video or Shorts link.');
      return;
    }

    setState(() {
      _isFetching = true;
      _errorMessage = null;
      _videoInfo = null;
    });

    final res = await ApiService.getVideoDownloadInfo(url);

    if (mounted) {
      setState(() {
        _isFetching = false;
        if (res['success'] == true) {
          _videoInfo = res;
        } else {
          _errorMessage = res['error'] ?? 'Failed to fetch YouTube details. Please verify the URL.';
        }
      });
    }
  }

  Future<void> _downloadStream(String downloadUrl) async {
    final uri = Uri.parse(downloadUrl);
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
        title: Text('YouTube Video Downloader', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary)),
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
                      : [const Color(0xFFFEF2F2), const Color(0xFFFEE2E2)],
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
                      color: Colors.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.play_circle_filled_rounded, color: Colors.red, size: 30),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('YouTube Video & Audio Saver', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary)),
                        const SizedBox(height: 4),
                        Text('Download YouTube videos, Shorts, and high-quality MP3 audio tracks directly to your device.', style: TextStyle(fontSize: 12.5, color: textSecondary, height: 1.35)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Input Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderCol),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Paste YouTube URL:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _urlController,
                    decoration: InputDecoration(
                      hintText: 'https://www.youtube.com/watch?v=... or /shorts/...',
                      hintStyle: TextStyle(color: textSecondary, fontSize: 13),
                      prefixIcon: const Icon(Icons.link_rounded, color: Colors.red, size: 20),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF191D30) : const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isFetching ? null : _fetchYoutubeInfo,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isFetching
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SpinKitRing(color: Colors.white, size: 18, lineWidth: 2),
                                SizedBox(width: 10),
                                Text('Fetching Video Details...', style: TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            )
                          : const Text('Fetch Download Options', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
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
                    Expanded(child: Text(_errorMessage!, style: const TextStyle(color: AppTheme.errorRed, fontSize: 13))),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Video Details & Stream Options
            if (_videoInfo != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderCol),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_videoInfo!['thumbnail'] != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          _videoInfo!['thumbnail'],
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Text(
                      _videoInfo!['title'] ?? 'YouTube Video',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary),
                    ),
                    if (_videoInfo!['author'] != null) ...[
                      const SizedBox(height: 4),
                      Text('Channel: ${_videoInfo!["author"]}', style: TextStyle(fontSize: 12.5, color: textSecondary)),
                    ],
                    const SizedBox(height: 16),
                    Text('Available Qualities:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary)),
                    const SizedBox(height: 10),
                    if (_videoInfo!['formats'] is List) ...[
                      ...(_videoInfo!['formats'] as List).map((fmt) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF191D30) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: borderCol),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    fmt['quality'] ?? fmt['format_note'] ?? 'HD Video',
                                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: textPrimary),
                                  ),
                                  Text(
                                    fmt['ext']?.toString().toUpperCase() ?? 'MP4',
                                    style: TextStyle(fontSize: 11, color: textSecondary),
                                  ),
                                ],
                              ),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.download_rounded, size: 16),
                                label: const Text('Download'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.accentEmerald,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () => _downloadStream(fmt['url']),
                              ),
                            ],
                          ),
                        );
                      }),
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.download_rounded, size: 18),
                          label: const Text('Download Video (MP4)'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentEmerald,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () => _downloadStream(_videoInfo!['download_url']),
                        ),
                      ),
                    ],
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
