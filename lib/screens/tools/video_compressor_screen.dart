import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/download_service.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';

const int kFreeDailyLimit = 3;
const int kMaxFreeUploadMb = 50;
const int kMaxProUploadMb = 100;

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
}

String getTodayUsageKey() {
  final today = DateTime.now().toIso8601String().substring(0, 10);
  return 'axom_vc_usage_$today';
}

class VideoCompressorScreen extends StatefulWidget {
  const VideoCompressorScreen({super.key});

  @override
  State<VideoCompressorScreen> createState() => _VideoCompressorScreenState();
}

class _VideoCompressorScreenState extends State<VideoCompressorScreen> {
  String _selectedPreset = 'whatsapp';
  bool _isPro = false;
  int _dailyUsage = 0;

  PlatformFile? _selectedVideo;
  bool _isCompressing = false;
  String _progressMsg = '';
  int _progressPercent = 0;
  String? _errorMessage;
  String? _taskId;
  Timer? _pollTimer;

  Map<String, dynamic>? _result;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _downloadStatusMsg = '';
  DownloadResult? _downloadResult;

  final List<Map<String, dynamic>> _presets = [
    {
      'id': 'whatsapp',
      'label': 'WhatsApp (720p)',
      'desc': '~80-85% size reduction, instant sharing',
      'icon': Icons.chat_bubble_rounded,
      'isPro': false,
    },
    {
      'id': 'instagram',
      'label': 'Reels & Stories (1080p)',
      'desc': '~60-65% reduction, crisp & vivid colors',
      'icon': Icons.video_collection_rounded,
      'isPro': false,
    },
    {
      'id': 'email',
      'label': 'Email Compact (480p)',
      'desc': '~85-90% reduction, under 15MB limit',
      'icon': Icons.mail_rounded,
      'isPro': false,
    },
    {
      'id': 'youtube',
      'label': 'Studio HD (1080p)',
      'desc': 'Maximum fidelity & high audio bitrate',
      'icon': Icons.hd_rounded,
      'isPro': true,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadUsageAndPlan();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUsageAndPlan() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = getTodayUsageKey();
      final count = prefs.getInt(key) ?? 0;
      final user = await AuthService.getCurrentUser();

      if (mounted) {
        setState(() {
          _dailyUsage = count;
          _isPro = user.isStaff;
        });
      }
    } catch (_) {}
  }

  Future<void> _incrementDailyUsage() async {
    if (_isPro) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = getTodayUsageKey();
      final newCount = _dailyUsage + 1;
      await prefs.setInt(key, newCount);
      if (mounted) {
        setState(() => _dailyUsage = newCount);
      }
    } catch (_) {}
  }

  void _resetAll() {
    _pollTimer?.cancel();
    setState(() {
      _selectedVideo = null;
      _isCompressing = false;
      _progressMsg = '';
      _progressPercent = 0;
      _errorMessage = null;
      _taskId = null;
      _result = null;
      _isDownloading = false;
      _downloadProgress = 0.0;
      _downloadStatusMsg = '';
      _downloadResult = null;
    });
  }

  Future<void> _pickVideo() async {
    setState(() => _errorMessage = null);

    if (!_isPro && _dailyUsage >= kFreeDailyLimit) {
      setState(() {
        _errorMessage =
            'Daily free limit reached ($kFreeDailyLimit/$kFreeDailyLimit videos). Please upgrade to Pro for unlimited encoding.';
      });
      return;
    }

    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp4', 'mov', 'mkv', 'avi', 'webm', '3gp', 'm4v'],
        withData: true,
      );

      if (res == null || res.files.isEmpty) return;

      final file = res.files.first;
      final maxBytes = (_isPro ? kMaxProUploadMb : kMaxFreeUploadMb) * 1024 * 1024;
      if (file.size > maxBytes) {
        setState(() {
          _errorMessage =
              'Video exceeds the ${_isPro ? kMaxProUploadMb : kMaxFreeUploadMb}MB limit. ${_isPro ? "" : "Upgrade to Pro for up to 100MB files."}';
        });
        return;
      }

      setState(() {
        _selectedVideo = file;
        _result = null;
        _errorMessage = null;
        _downloadResult = null;
      });
    } catch (e) {
      setState(() => _errorMessage = 'Could not select video: $e');
    }
  }

  Future<void> _startCompression() async {
    if (_selectedVideo == null) return;

    final presetConfig = _presets.firstWhere((p) => p['id'] == _selectedPreset);
    if (presetConfig['isPro'] == true && !_isPro) {
      _showUpgradeModal();
      return;
    }

    if (!_isPro && _dailyUsage >= kFreeDailyLimit) {
      setState(() {
        _errorMessage =
            'Daily limit reached ($kFreeDailyLimit/$kFreeDailyLimit videos). Upgrade to Pro for unlimited priority encoding.';
      });
      _showUpgradeModal();
      return;
    }

    setState(() {
      _isCompressing = true;
      _errorMessage = null;
      _result = null;
      _progressMsg = 'Uploading video to server...';
      _progressPercent = 10;
      _downloadResult = null;
    });

    try {
      final uploadRes = await ApiService.uploadVideoCompress(
        file: _selectedVideo!,
        preset: _selectedPreset,
      );

      if (!mounted) return;

      if (uploadRes['upgrade_required'] == true) {
        setState(() {
          _isCompressing = false;
          _errorMessage = uploadRes['error'] ?? 'Upgrade required for this preset or file size.';
        });
        _showUpgradeModal();
        return;
      }

      if (uploadRes['success'] == true && uploadRes['task_id'] != null) {
        _taskId = uploadRes['task_id'] as String;
        setState(() {
          _progressMsg = 'Dispatched to FFmpeg encoder...';
          _progressPercent = 25;
        });
        _pollStatus();
      } else {
        setState(() {
          _isCompressing = false;
          _errorMessage = uploadRes['error'] ?? 'Video upload failed. Please try again.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCompressing = false;
          _errorMessage = 'An error occurred: $e';
        });
      }
    }
  }

  void _pollStatus() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (_taskId == null) {
        timer.cancel();
        return;
      }

      final res = await ApiService.checkVideoCompressStatus(_taskId!);
      final status = res['status']?.toString().toLowerCase();

      if (!mounted) {
        timer.cancel();
        return;
      }

      if (status == 'completed' || status == 'success') {
        timer.cancel();
        await _incrementDailyUsage();
        setState(() {
          _isCompressing = false;
          _progressPercent = 100;
          _progressMsg = 'Compression complete!';
          _result = res;
        });

        _autoDownloadResult(res);
      } else if (status == 'failed' || status == 'error') {
        timer.cancel();
        setState(() {
          _isCompressing = false;
          _errorMessage = res['error'] ?? 'Video compression failed.';
        });
      } else {
        final prog = (res['progress'] is num) ? (res['progress'] as num).toInt() : 45;
        setState(() {
          _progressPercent = prog > 25 ? prog : 40;
          _progressMsg = prog > 60
              ? 'Optimizing audio bitrates & fast-start flags...'
              : 'Encoding frames with FFmpeg H.264...';
        });
      }
    });
  }

  Future<void> _autoDownloadResult(Map<String, dynamic> res) async {
    final dlUrl = res['download_url'] as String?;
    if (dlUrl == null) return;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.05;
      _downloadStatusMsg = 'Preparing video player stream...';
    });

    final defaultFilename = res['output_filename'] as String? ??
        'axom_compressed_${_selectedVideo?.name ?? "video.mp4"}';

    final downloadRes = await DownloadService.downloadToAppStorage(
      rawUrl: dlUrl,
      preferredFilename: defaultFilename,
      onProgress: (p, msg) {
        if (mounted) {
          setState(() {
            _downloadProgress = p;
            _downloadStatusMsg = msg;
          });
        }
      },
    );

    if (mounted) {
      setState(() {
        _isDownloading = false;
        _downloadResult = downloadRes;
      });
    }
  }

  Future<void> _saveWithNativeDialog() async {
    final dlUrl = _result?['download_url'] as String?;
    if (dlUrl == null) return;

    final defaultFilename = _result?['output_filename'] as String? ??
        'axom_compressed_${_selectedVideo?.name ?? "video.mp4"}';

    if (_downloadResult == null || !_downloadResult!.success || _downloadResult!.filePath == null) {
      await _autoDownloadResult(_result!);
    }

    if (_downloadResult != null && _downloadResult!.filePath != null) {
      await DownloadService.promptNativeSaveDialog(
        filePath: _downloadResult!.filePath!,
        fileName: defaultFilename,
        isBatch: false,
        customExtension: 'mp4',
      );
    }
  }

  Future<void> _playVideo() async {
    final dlUrl = _result?['download_url'] as String? ?? '';
    final filePath = _downloadResult?.filePath;

    if (filePath == null) {
      if (dlUrl.isNotEmpty) {
        await DownloadService.openInGoogleDriveViewer(dlUrl);
      }
      return;
    }

    final openRes = await DownloadService.openFile(filePath);
    if (openRes.type != ResultType.done && mounted) {
      if (dlUrl.isNotEmpty) {
        await DownloadService.openInGoogleDriveViewer(dlUrl);
      }
    }
  }

  Future<void> _shareVideo() async {
    final filePath = _downloadResult?.filePath;
    if (filePath != null) {
      await DownloadService.shareFile(
        filePath,
        text: 'Compressed with Axom AI Video Compressor ⭐',
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait, preparing video for sharing...'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showUpgradeModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _buildUpgradeSheet(),
    );
  }

  Widget _buildUpgradeSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? AppTheme.bgCard : Colors.white;
    final textPrimary = isDark ? AppTheme.textPrimary : const Color(0xFF0F172A);
    final textSecondary = isDark ? AppTheme.textSecondary : const Color(0xFF64748B);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.workspace_premium_rounded,
                color: Color(0xFFF59E0B), size: 28),
          ),
          const SizedBox(height: 14),
          Text(
            'Upgrade to Axom AI Pro',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            'Unlock up to 100MB video uploads, 50 daily conversions, Studio HD 1080p encoding, and priority GPU processing queue.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: textSecondary, height: 1.45),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Razorpay integration is active on web. Subscription syncing to app...'),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text('Upgrade to Pro — ₹99/month',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgCol = isDark ? AppTheme.bgDark : const Color(0xFFF8FAFC);
    final cardBg = isDark ? AppTheme.bgCard : Colors.white;
    final borderCol = isDark ? AppTheme.borderColor : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? AppTheme.textPrimary : const Color(0xFF0F172A);
    final textSecondary =
        isDark ? AppTheme.textSecondary : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bgCol,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Video Compressor',
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
            Text(
              'FFmpeg H.264 Hardware Acceleration',
              style: TextStyle(
                fontSize: 11,
                color: textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: borderCol, height: 1),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderCol),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.electric_bolt_rounded,
                  size: 14,
                  color: _isPro
                      ? const Color(0xFF10B981)
                      : const Color(0xFFF59E0B),
                ),
                const SizedBox(width: 4),
                Text(
                  _isPro
                      ? 'Pro VIP'
                      : '${kFreeDailyLimit - _dailyUsage} left',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── ERROR BANNER ──────────────────────────────────────────
            if (_errorMessage != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded,
                        color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.red.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ─── UPLOAD ZONE ───────────────────────────────────────────
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _selectedVideo != null
                      ? const Color(0xFF6366F1).withValues(alpha: 0.5)
                      : borderCol,
                  width: _selectedVideo != null ? 1.5 : 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    if (_selectedVideo == null) ...[
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF6366F1).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.video_camera_back_rounded,
                          color: Color(0xFF6366F1),
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Select Video to Compress',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Supports MP4, MOV, MKV, AVI, WebM • Max ${_isPro ? kMaxProUploadMb : kMaxFreeUploadMb}MB',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11.5, color: textSecondary),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton.icon(
                          onPressed: _pickVideo,
                          icon: const Icon(Icons.file_upload_outlined, size: 18),
                          label: const Text('Choose Video File'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF6366F1),
                            side:
                                const BorderSide(color: Color(0xFF6366F1)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      // File Info Bar
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1)
                                  .withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.movie_creation_rounded,
                              color: Color(0xFF6366F1),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedVideo!.name,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  formatBytes(_selectedVideo!.size),
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 20),
                            color: textSecondary,
                            onPressed: _resetAll,
                            tooltip: 'Clear',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Presets List
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Compression Target Profile',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      Column(
                        children: _presets.map((preset) {
                          final isSelected = _selectedPreset == preset['id'];
                          final isProPreset = preset['isPro'] == true;

                          return GestureDetector(
                            onTap: () {
                              if (isProPreset && !_isPro) {
                                _showUpgradeModal();
                              } else {
                                setState(() => _selectedPreset = preset['id']);
                              }
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF6366F1)
                                        .withValues(alpha: 0.08)
                                    : (isDark
                                        ? const Color(0xFF1E293B)
                                        : const Color(0xFFF8FAFC)),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF6366F1)
                                      : borderCol,
                                  width: isSelected ? 1.5 : 1.0,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    preset['icon'] as IconData,
                                    color: isSelected
                                        ? const Color(0xFF6366F1)
                                        : textSecondary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              preset['label'] as String,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: isSelected
                                                    ? const Color(0xFF6366F1)
                                                    : textPrimary,
                                              ),
                                            ),
                                            if (isProPreset) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 1.5),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFF59E0B)
                                                      .withValues(alpha: 0.15),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: const Text(
                                                  'PRO ⭐',
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFFF59E0B),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          preset['desc'] as String,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    isSelected
                                        ? Icons.radio_button_checked_rounded
                                        : Icons.radio_button_off_rounded,
                                    size: 18,
                                    color: isSelected
                                        ? const Color(0xFF6366F1)
                                        : textSecondary.withValues(alpha: 0.5),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 14),

                      // Compress CTA Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isCompressing ? null : _startCompression,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: _isCompressing
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const SpinKitRing(
                                      color: Colors.white,
                                      size: 20,
                                      lineWidth: 2.2,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      _progressMsg.isNotEmpty
                                          ? _progressMsg
                                          : 'Compressing Video...',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.video_settings_rounded,
                                        size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Compress Video Now',
                                      style: TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 18),

            // ─── PROGRESS CARD DURING ENCODE ───────────────────────────
            if (_isCompressing) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Encoding in Progress...',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                        Text(
                          '$_progressPercent%',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6366F1),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: _progressPercent / 100,
                        backgroundColor: borderCol,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF6366F1),
                        ),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _progressMsg,
                      style: TextStyle(fontSize: 11.5, color: textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],

            // ─── COMPLETED RESULT CARD ─────────────────────────────────
            if (_result != null && (_result!['status'] == 'completed' || _result!['status'] == 'success')) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          const Color(0xFF10B981).withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981)
                                .withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF10B981),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Video Compressed Successfully!',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _calculateSavingsText(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Metrics Banner
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF131D31)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderCol),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildSizeMetric(
                            'Original',
                            formatBytes(_result!['input_size'] is int
                                ? _result!['input_size'] as int
                                : _selectedVideo?.size ?? 0),
                            textSecondary,
                            textPrimary,
                          ),
                          Container(width: 1, height: 26, color: borderCol),
                          _buildSizeMetric(
                            'Compressed',
                            formatBytes(_result!['output_size'] is int
                                ? _result!['output_size'] as int
                                : 0),
                            textSecondary,
                            const Color(0xFF10B981),
                          ),
                          Container(width: 1, height: 26, color: borderCol),
                          _buildSizeMetric(
                            'Reduction',
                            _calculateSavingsPercent(),
                            textSecondary,
                            const Color(0xFFF59E0B),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                    if (_isDownloading) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.25)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _downloadStatusMsg,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: textPrimary,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${(_downloadProgress * 100).toInt()}%',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF4F46E5),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: _downloadProgress,
                                backgroundColor: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
                                minHeight: 4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],


                    // Action 1: Native Storage Access Framework Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton.icon(
                        onPressed: _saveWithNativeDialog,
                        icon: const Icon(Icons.download_rounded, size: 20),
                        label: const Text(
                          'Save Video to Device (SAF Modal)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Action 2 & 3: Play Video Chooser & Share
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _playVideo,
                            icon: const Icon(Icons.play_arrow_rounded, size: 19),
                            label: const Text('Play Video'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: textPrimary,
                              side: BorderSide(color: borderCol),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 11),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _shareVideo,
                            icon: const Icon(Icons.share_rounded, size: 17),
                            label: const Text('Share'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: textPrimary,
                              side: BorderSide(color: borderCol),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 11),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ─── 1 CARD PER ROW TRUST HIGHLIGHTS ───────────────────────
            Text(
              'Why Axom AI Video Compressor',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            _buildFeatureCard(
              icon: Icons.speed_rounded,
              color: const Color(0xFF6366F1),
              title: 'Hardware Accelerated FFmpeg',
              description:
                  'Multi-threaded H.264 video compression ensures fast rendering without losing audio sync or frame clarity.',
              isDark: isDark,
              cardBg: cardBg,
              borderCol: borderCol,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
            const SizedBox(height: 10),

            _buildFeatureCard(
              icon: Icons.tune_rounded,
              color: const Color(0xFF10B981),
              title: 'Optimized Social Presets',
              description:
                  'Ready-made profiles for WhatsApp, Instagram Reels, and Email ensure your videos pass upload limits effortlessly.',
              isDark: isDark,
              cardBg: cardBg,
              borderCol: borderCol,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
            const SizedBox(height: 10),

            _buildFeatureCard(
              icon: Icons.lock_outline_rounded,
              color: const Color(0xFFF59E0B),
              title: 'Automatic Privacy Cleanup',
              description:
                  'Original raw files are wiped immediately upon compression. Encoded videos are deleted after 1 hour.',
              isDark: isDark,
              cardBg: cardBg,
              borderCol: borderCol,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  String _calculateSavingsText() {
    final inBytes = (_result?['input_size'] is int)
        ? _result!['input_size'] as int
        : (_selectedVideo?.size ?? 0);
    final outBytes = (_result?['output_size'] is int)
        ? _result!['output_size'] as int
        : 0;

    if (inBytes > 0 && outBytes > 0 && outBytes < inBytes) {
      final savedPct = ((inBytes - outBytes) / inBytes * 100).round();
      return 'Saved $savedPct% storage space ⭐';
    }
    return 'Optimized video streams successfully';
  }

  String _calculateSavingsPercent() {
    final inBytes = (_result?['input_size'] is int)
        ? _result!['input_size'] as int
        : (_selectedVideo?.size ?? 0);
    final outBytes = (_result?['output_size'] is int)
        ? _result!['output_size'] as int
        : 0;

    if (inBytes > 0 && outBytes > 0 && outBytes < inBytes) {
      final savedPct = ((inBytes - outBytes) / inBytes * 100).round();
      return '-$savedPct%';
    }
    return '-';
  }

  Widget _buildSizeMetric(
      String title, String val, Color labelColor, Color valColor) {
    return Column(
      children: [
        Text(title, style: TextStyle(fontSize: 11, color: labelColor)),
        const SizedBox(height: 2),
        Text(
          val,
          style: TextStyle(
              fontSize: 13.5, fontWeight: FontWeight.bold, color: valColor),
        ),
      ],
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
    required bool isDark,
    required Color cardBg,
    required Color borderCol,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
