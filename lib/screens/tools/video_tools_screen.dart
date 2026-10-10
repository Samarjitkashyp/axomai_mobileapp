import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

class VideoToolsScreen extends StatefulWidget {
  final bool initialIsDownloader;
  const VideoToolsScreen({super.key, this.initialIsDownloader = false});

  @override
  State<VideoToolsScreen> createState() => _VideoToolsScreenState();
}

class _VideoToolsScreenState extends State<VideoToolsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Compressor State
  PlatformFile? _selectedVideo;
  String _targetQuality = 'medium'; // 'low', 'medium', 'high'
  bool _isCompressing = false;
  String? _taskId;
  Timer? _statusTimer;
  Map<String, dynamic>? _compressResult;
  String? _compressError;

  // Downloader State
  final TextEditingController _urlController = TextEditingController();
  bool _isFetchingVideo = false;
  Map<String, dynamic>? _videoInfo;
  String? _downloadError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialIsDownloader ? 1 : 0);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _urlController.dispose();
    _statusTimer?.cancel();
    super.dispose();
  }

  // ─── COMPRESSOR ───────────────────────────────────────────────────
  Future<void> _pickVideo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedVideo = result.files.first;
          _compressResult = null;
          _compressError = null;
        });
      }
    } catch (e) {
      setState(() => _compressError = 'Video selection error: $e');
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
          _compressError = res['error'] ?? 'Compression upload failed.';
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

  // ─── DOWNLOADER ───────────────────────────────────────────────────
  Future<void> _fetchVideoDownloadInfo() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _isFetchingVideo = true;
      _downloadError = null;
      _videoInfo = null;
    });

    final res = await ApiService.getVideoDownloadInfo(url);
    if (!mounted) return;
    setState(() {
      _isFetchingVideo = false;
      if (res['success'] == true || res['formats'] != null || res['title'] != null) {
        _videoInfo = res;
      } else {
        _downloadError = res['error'] ?? 'Could not extract video details from URL.';
      }
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Video Tools Suite', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accentPurple,
          labelColor: AppTheme.accentPurple,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: const [
            Tab(icon: Icon(Icons.compress_rounded), text: 'Compress Video'),
            Tab(icon: Icon(Icons.download_rounded), text: 'Download Video'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCompressorTab(),
          _buildDownloaderTab(),
        ],
      ),
    );
  }

  Widget _buildCompressorTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.accentPurple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.accentPurple.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.video_file_rounded, color: AppTheme.accentPurple, size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'High quality FFmpeg server-side video compression. Shrink 4K/1080p MP4 videos up to 80% without visible quality loss.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Upload
          GestureDetector(
            onTap: _pickVideo,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.bgSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _selectedVideo != null ? AppTheme.accentPurple : AppTheme.glassBorder,
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    _selectedVideo != null ? Icons.check_circle_rounded : Icons.cloud_upload_outlined,
                    size: 40,
                    color: _selectedVideo != null ? AppTheme.accentPurple : AppTheme.textSecondary,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _selectedVideo != null ? _selectedVideo!.name : 'Click to select video (MP4, MKV, MOV)',
                    style: TextStyle(
                      color: _selectedVideo != null ? AppTheme.textPrimary : AppTheme.textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_selectedVideo != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Original Size: ${(_selectedVideo!.size / (1024 * 1024)).toStringAsFixed(2)} MB',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Target Quality
          const Text('Compression Preset', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildQualityChip('Small Size', 'low', 'Maximum compression'),
              const SizedBox(width: 8),
              _buildQualityChip('Balanced', 'medium', 'Recommended'),
              const SizedBox(width: 8),
              _buildQualityChip('High Res', 'high', 'Minimal compression'),
            ],
          ),
          const SizedBox(height: 20),

          if (_selectedVideo != null)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isCompressing ? null : _startCompression,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentPurple,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isCompressing
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SpinKitRing(color: Colors.white, size: 20, lineWidth: 2),
                          SizedBox(width: 12),
                          Text('Compressing video on GPU cluster...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      )
                    : const Text('Compress Video Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ),

          if (_compressError != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.accentPink.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.accentPink.withOpacity(0.3)),
              ),
              child: Text(_compressError!, style: const TextStyle(color: AppTheme.accentPink, fontSize: 13)),
            ),
          ],

          if (_compressResult != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.successGreen.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.successGreen.withOpacity(0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Video Compressed Successfully! 🎉', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 8),
                  Text('Compressed Size: ${_compressResult!['new_size'] ?? 'Reduced'} (Saved ${_compressResult!['saved_percentage'] ?? '50%'})', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final url = _compressResult!['download_url'];
                      if (url != null) {
                        final uri = Uri.parse(url);
                        if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Download Compressed Video'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successGreen, foregroundColor: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQualityChip(String title, String val, String subtitle) {
    final isSelected = _targetQuality == val;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _targetQuality = val),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.accentPurple.withOpacity(0.15) : AppTheme.bgSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? AppTheme.accentPurple : AppTheme.glassBorder),
          ),
          child: Column(
            children: [
              Text(title, style: TextStyle(color: isSelected ? AppTheme.accentPurple : AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 9), maxLines: 1),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDownloaderTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Enter Public Video URL', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          TextField(
            controller: _urlController,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Paste YouTube, Instagram, or direct video link...',
              hintStyle: const TextStyle(color: AppTheme.textSecondary),
              filled: true,
              fillColor: AppTheme.bgSurface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0x14FFFFFF))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0x14FFFFFF))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.accentPurple)),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isFetchingVideo ? null : _fetchVideoDownloadInfo,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentPurple,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isFetchingVideo
                  ? const SpinKitRing(color: Colors.white, size: 20, lineWidth: 2)
                  : const Text('Extract Video Streams', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),

          if (_downloadError != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.accentPink.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.accentPink.withOpacity(0.3)),
              ),
              child: Text(_downloadError!, style: const TextStyle(color: AppTheme.accentPink, fontSize: 13)),
            ),
          ],

          if (_videoInfo != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.bgSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.glassBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_videoInfo!['title'] ?? 'Video Stream Extracted', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 12),
                  if (_videoInfo!['download_url'] != null)
                    ElevatedButton.icon(
                      onPressed: () async {
                        final uri = Uri.parse(_videoInfo!['download_url']);
                        if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                      },
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('Download Highest Quality Stream'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentCyan, foregroundColor: Colors.black),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
